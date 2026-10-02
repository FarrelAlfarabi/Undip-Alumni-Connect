import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_config.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';

import '../support/fake_lock.dart';

void main() {
  group('remembering a person', () {
    test('stores only id, display name and a masked email', () async {
      final store = MemoryLockStore();
      final lock = makeLock(store: store);
      await lock.remember(
        profileId: 'p1',
        displayName: 'Ahmad Ramadhan',
        email: testEmail,
      );
      expect(store.data.length, 3);
      final all = store.data.values.join('|');
      expect(all.contains(testEmail), isFalse);
      expect(all.contains('ahmad.ramadhan'), isFalse);
      final user = await lock.load();
      expect(user!.profileId, 'p1');
      expect(user.displayName, 'Ahmad Ramadhan');
      expect(user.maskedEmail, 'a***@example.com');
    });

    test('nothing remembered means load() is null', () async {
      expect(await makeLock().load(), isNull);
    });

    test('a different person drops the old PIN and biometric choice', () async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await lock.setBiometricsEnabled(true);
      await lock.remember(
        profileId: 'p2',
        displayName: 'Bunga',
        email: 'bunga@example.com',
      );
      expect(await lock.hasPin(), isFalse);
      expect((await lock.load())!.profileId, 'p2');
    });

    test('same person again keeps the PIN', () async {
      final lock = await makeRememberedLock();
      await lock.remember(
        profileId: 'p1',
        displayName: 'Ahmad Ramadhan',
        email: testEmail,
      );
      expect(await lock.hasPin(), isTrue);
    });

    test('disabled service (web) remembers nothing', () async {
      final store = MemoryLockStore();
      final lock = makeLock(store: store, enabled: false);
      await lock.remember(profileId: 'p1', displayName: 'A', email: testEmail);
      expect(store.data, isEmpty);
      expect(await lock.load(), isNull);
    });
  });

  group('PIN storage', () {
    test('stores a salted hash, never the PIN', () async {
      final store = MemoryLockStore();
      final lock = makeLock(store: store);
      await lock.setPin(testPin);
      final all = store.data.values.join('|');
      expect(all.contains(testPin), isFalse);
      expect(all.contains(r'pbkdf2-sha256$'), isTrue);
    });
  });

  group('checking a PIN', () {
    test('correct PIN', () async {
      final lock = await makeRememberedLock();
      expect(await lock.checkPin(testPin), isA<PinOk>());
    });

    test('wrong PIN counts down attempts', () async {
      final lock = await makeRememberedLock();
      final r = await lock.checkPin('000001') as PinWrong;
      expect(r.attemptsLeft, kMaxPinAttempts - 1);
      expect(r.waitUntil, isNull);
      expect(await lock.attemptsLeft(), kMaxPinAttempts - 1);
    });

    test('a correct PIN resets the counter', () async {
      final lock = await makeRememberedLock();
      await lock.checkPin('000001');
      await lock.checkPin('000002');
      expect(await lock.checkPin(testPin), isA<PinOk>());
      expect(await lock.attemptsLeft(), kMaxPinAttempts);
    });

    test(
      '3rd wrong try starts a delay; tries in the delay are not counted',
      () async {
        final clock = FakeClock();
        final lock = await makeRememberedLock(clock: clock);
        await lock.checkPin('000001');
        await lock.checkPin('000002');
        final third = await lock.checkPin('000003') as PinWrong;
        expect(third.attemptsLeft, 2);
        expect(third.waitUntil, clock.now.add(kWrongPinDelay));

        // Even the right PIN is refused while waiting, and nothing is counted.
        expect(await lock.checkPin(testPin), isA<PinWait>());
        expect(await lock.checkPin('999999'), isA<PinWait>());
        expect(await lock.attemptsLeft(), 2);

        clock.advance(kWrongPinDelay + const Duration(seconds: 1));
        expect(await lock.waitUntil(), isNull);
        expect(await lock.checkPin(testPin), isA<PinOk>());
      },
    );

    test('5th wrong PIN wipes all local unlock data', () async {
      final clock = FakeClock();
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store, clock: clock);
      PinCheck? last;
      for (var i = 0; i < kMaxPinAttempts; i++) {
        last = await lock.checkPin('00000$i');
        clock.advance(kWrongPinDelay + const Duration(seconds: 1));
      }
      expect(last, isA<PinLockedOut>());
      expect(store.data, isEmpty);
      expect(await lock.load(), isNull);
      expect(await lock.hasPin(), isFalse);
      expect(lock.sessionActive, isFalse);
    });

    test('attempts survive an app restart (same store, new service)', () async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await lock.checkPin('000001');
      await lock.checkPin('000002');
      final restarted = makeLock(store: store);
      expect(await restarted.attemptsLeft(), kMaxPinAttempts - 2);
    });

    test('setting a new PIN resets attempts and delay', () async {
      final lock = await makeRememberedLock();
      await lock.checkPin('000001');
      await lock.setPin('735019');
      expect(await lock.attemptsLeft(), kMaxPinAttempts);
      expect(await lock.checkPin('735019'), isA<PinOk>());
    });
  });

  group('signOut', () {
    test('forgets the person but keeps the PIN', () async {
      final lock = await makeRememberedLock();
      lock.sessionActive = true;
      await lock.signOut();
      expect(await lock.load(), isNull);
      expect(await lock.hasPin(), isTrue);
      expect(lock.sessionActive, isFalse);
    });

    test(
      'the same person signing in again still has the PIN, which works',
      () async {
        final lock = await makeRememberedLock();
        await lock.signOut();
        await lock.remember(
          profileId: 'p1',
          displayName: 'Ahmad Ramadhan',
          email: testEmail,
        );
        expect(await lock.hasPin(), isTrue);
        expect(await lock.checkPin(testPin), isA<PinOk>());
      },
    );

    test('a different person signing in drops the old PIN', () async {
      final lock = await makeRememberedLock();
      await lock.signOut();
      await lock.remember(
        profileId: 'p2',
        displayName: 'Bunga',
        email: 'bunga@example.com',
      );
      expect(await lock.hasPin(), isFalse);
    });

    test('wrong tries are not reset by signing out', () async {
      final lock = await makeRememberedLock();
      await lock.checkPin('111112');
      await lock.signOut();
      expect(await lock.attemptsLeft(), kMaxPinAttempts - 1);
    });
  });

  group('clear (switch account, forgot PIN, sign out)', () {
    test('wipes everything local and ends the session', () async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      lock.sessionActive = true;
      await lock.clear();
      expect(store.data, isEmpty);
      expect(await lock.load(), isNull);
      expect(lock.sessionActive, isFalse);
    });
  });

  group('biometrics flag', () {
    test('is on only when chosen and the device still supports it', () async {
      final bio = FakeBiometrics();
      final lock = await makeRememberedLock(bio: bio);
      expect(await lock.biometricsEnabled(), isFalse);
      await lock.setBiometricsEnabled(true);
      expect(await lock.biometricsEnabled(), isTrue);
      bio.available = false;
      expect(await lock.biometricsEnabled(), isFalse);
    });
  });
}
