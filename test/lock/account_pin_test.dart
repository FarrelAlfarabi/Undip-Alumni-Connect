// One PIN per account (24 Nov 2026): a PIN made on the laptop opens the
// phone and the other way round. The database keeps a bcrypt hash of it and
// counts wrong tries for the account; each device keeps a cached hash only so
// it still opens without internet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_screen.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/lock/pin_setup_screen.dart';

import '../support/fake_lock.dart';
import '../support/fake_pin_server.dart';

Future<LockService> device(
  FakePinServer server, {
  MemoryLockStore? store,
  FakeClock? clock,
  String profileId = 'p1',
}) async {
  final lock = makeLock(store: store, server: server, clock: clock);
  await lock.remember(
    profileId: profileId,
    displayName: 'Ahmad Ramadhan',
    email: testEmail,
  );
  await lock.syncFromAccount();
  return lock;
}

void main() {
  late FakeClock clock;
  late FakePinServer server;

  setUp(() {
    clock = FakeClock();
    server = FakePinServer(clock: clock.call);
  });

  test('a PIN made on the laptop opens the phone', () async {
    final laptop = await device(server, clock: clock);
    await laptop.setPin(testPin);
    expect(server.pin, testPin);

    final phone = await device(server, clock: clock);
    expect(await phone.hasPin(), isTrue, reason: 'no new PIN to make');
    expect(await phone.checkPin(testPin), isA<PinOk>());
  });

  test('a PIN changed on the phone is the one the laptop asks for', () async {
    final laptop = await device(server, clock: clock);
    await laptop.setPin(testPin);
    final phone = await device(server, clock: clock);
    await phone.setPin('730518');
    expect(await laptop.checkPin(testPin), isA<PinWrong>());
    expect(await laptop.checkPin('730518'), isA<PinOk>());
  });

  test(
    'the PIN is not saved anywhere when the account cannot be reached',
    () async {
      final lock = await device(server, clock: clock);
      server.offline = true;
      await expectLater(lock.setPin(testPin), throwsA(isA<PinSyncException>()));
      expect(await lock.hasPin(), isFalse);
      expect(server.pin, isNull);
    },
  );

  test('wrong tries count for the account, not per device', () async {
    final laptop = await device(server, clock: clock);
    await laptop.setPin(testPin);
    final phone = await device(server, clock: clock);
    expect(await laptop.checkPin('000001'), isA<PinWrong>());
    final r = await phone.checkPin('000002');
    expect(r, isA<PinWrong>());
    expect((r as PinWrong).attemptsLeft, 3);
  });

  test('the 5th wrong PIN on one device signs out every device', () async {
    final laptop = await device(server, clock: clock);
    await laptop.setPin(testPin);
    final phone = await device(server, clock: clock);
    await phone.checkPin(testPin); // the phone has the PIN cached now
    PinCheck last = const PinOk();
    for (var i = 0; i < 5; i++) {
      last = await laptop.checkPin('00000$i');
      clock.advance(const Duration(seconds: 11));
    }
    expect(last, isA<PinLockedOut>());
    expect(server.pin, isNull);
    // The right PIN on the phone no longer opens it: verify by email again.
    final r = await phone.checkPin(testPin);
    expect(r, isA<PinLockedOut>());
    expect((r as PinLockedOut).resetElsewhere, isTrue);
    expect(await phone.hasPin(), isFalse);
  });

  test('a PIN from before this change is moved to the account', () async {
    final store = MemoryLockStore();
    final old = makeLock(store: store, clock: clock); // no account PIN then
    await old.remember(
      profileId: 'p1',
      displayName: 'Ahmad Ramadhan',
      email: testEmail,
    );
    await old.setPin(testPin);
    final now = makeLock(store: store, server: server, clock: clock);
    expect(await now.checkPin(testPin), isA<PinOk>());
    expect(server.pin, testPin, reason: 'other devices can use it now');
  });

  test('an old device PIN does not replace the account PIN', () async {
    server.pin = '730518'; // made on the laptop
    final store = MemoryLockStore();
    final old = makeLock(store: store, clock: clock);
    await old.remember(
      profileId: 'p1',
      displayName: 'Ahmad Ramadhan',
      email: testEmail,
    );
    await old.setPin(testPin); // the phone's own PIN from before
    final phone = makeLock(store: store, server: server, clock: clock);
    expect(await phone.checkPin(testPin), isA<PinOldDevicePin>());
    expect(server.pin, '730518');
    expect(await phone.checkPin('730518'), isA<PinOk>());
  });

  test(
    'without internet the PIN last used here still opens this device',
    () async {
      final lock = await device(server, clock: clock);
      await lock.setPin(testPin);
      server.offline = true;
      expect(await lock.checkPin(testPin), isA<PinOk>());
      expect(await lock.checkPin('000001'), isA<PinWrong>());
    },
  );

  test('without internet and no PIN cached here: ask to connect', () async {
    server.pin = testPin; // made on another device
    final phone = await device(server, clock: clock);
    server.offline = true;
    expect(await phone.checkPin(testPin), isA<PinOffline>());
  });

  test('Hapus PIN removes it from the account', () async {
    final lock = await device(server, clock: clock);
    await lock.setPin(testPin);
    await lock.removePin();
    expect(server.pin, isNull);
    expect(await lock.hasPin(), isFalse);
  });

  test(
    'a PIN removed on another device is dropped here at the next sign in',
    () async {
      final store = MemoryLockStore();
      final phone = await device(server, store: store, clock: clock);
      await phone.setPin(testPin);
      server.pin = null; // removed on the laptop
      final again = await device(server, store: store, clock: clock);
      expect(await again.hasPin(), isFalse);
    },
  );

  test(
    'another person on the same device never gets this account PIN flag',
    () async {
      server.pin = testPin;
      final store = MemoryLockStore();
      await device(server, store: store, clock: clock);
      final other = makeLock(
        store: store,
        server: FakePinServer(),
        clock: clock,
      );
      await other.remember(
        profileId: 'p2',
        displayName: 'Bunga',
        email: 'bunga@example.com',
      );
      await other.syncFromAccount();
      expect(await other.hasPin(), isFalse);
    },
  );

  test('the PIN never reaches the device store in plain text', () async {
    final store = MemoryLockStore();
    final lock = await device(server, store: store, clock: clock);
    await lock.setPin(testPin);
    expect(store.data.values.any((v) => v.contains(testPin)), isFalse);
  });

  test('changing the PIN needs the old one unless just signed in', () async {
    final laptop = await device(server, clock: clock);
    await laptop.setPin(testPin);
    server.recentSignIn = false;
    // A fresh device that never typed the PIN cannot replace it.
    final other = makeLock(server: server, clock: clock);
    await other.remember(
      profileId: 'p1',
      displayName: 'Ahmad Ramadhan',
      email: testEmail,
    );
    await other.syncFromAccount();
    await expectLater(
      other.setPin('730518'),
      throwsA(
        isA<PinSyncException>().having((e) => e.needsOldPin, 'old', true),
      ),
    );
    expect(server.pin, testPin);
    // After typing the right PIN ("Ubah PIN" asks for it), it can.
    expect(await other.checkPin(testPin), isA<PinOk>());
    await other.setPin('730518');
    expect(server.pin, '730518');
  });

  test(
    'opening the app after the PIN was removed elsewhere signs out',
    () async {
      final store = MemoryLockStore();
      final phone = await device(server, store: store, clock: clock);
      await phone.setPin(testPin);
      server.pin = null; // 5 wrong tries on the laptop
      final again = makeLock(store: store, server: server, clock: clock);
      expect(await again.syncFromAccount(), isTrue);
      expect(await again.hasPin(), isFalse);
    },
  );

  test('the old device PIN message shows once', () async {
    server.pin = '730518';
    final store = MemoryLockStore();
    final old = makeLock(store: store, clock: clock);
    await old.remember(
      profileId: 'p1',
      displayName: 'Ahmad Ramadhan',
      email: testEmail,
    );
    await old.setPin(testPin);
    final phone = makeLock(store: store, server: server, clock: clock);
    expect(await phone.checkPin(testPin), isA<PinOldDevicePin>());
    expect(await phone.checkPin(testPin), isA<PinWrong>());
    expect(await phone.hasPin(), isTrue);
  });

  group('screens', () {
    Future<void> phoneSize(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('lock screen explains an old device PIN', (tester) async {
      await phoneSize(tester);
      server.pin = '730518';
      final store = MemoryLockStore();
      final old = makeLock(store: store);
      await old.remember(
        profileId: 'p1',
        displayName: 'Ahmad Ramadhan',
        email: testEmail,
      );
      await old.setPin(testPin);
      final lock = makeLock(store: store, server: server);
      final user = (await lock.load())!;
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreen(
            lock: lock,
            user: user,
            onUnlocked: () async => opened = true,
            onSwitchAccount: () async {},
            onForgotPin: () async {},
            onLockedOut: () async {},
            onContinue: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterPin(tester, testPin);
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      expect(
        find.textContaining('satu PIN untuk semua perangkat'),
        findsOneWidget,
      );
    });

    testWidgets('lock screen asks for internet when the PIN is not here yet', (
      tester,
    ) async {
      await phoneSize(tester);
      server.pin = testPin;
      final lock = await device(server);
      server.offline = true;
      final user = (await lock.load())!;
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreen(
            lock: lock,
            user: user,
            onUnlocked: () async {},
            onSwitchAccount: () async {},
            onForgotPin: () async {},
            onLockedOut: () async {},
            onContinue: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterPin(tester, testPin);
      await tester.pumpAndSettle();
      expect(find.textContaining('internet'), findsOneWidget);
    });

    testWidgets('PIN setup shows an error and stays when saving fails', (
      tester,
    ) async {
      await phoneSize(tester);
      final lock = await device(server);
      server.offline = true;
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PinSetupScreen(lock: lock, onDone: (_) async => done = true),
        ),
      );
      await tester.pumpAndSettle();
      await enterPin(tester, testPin);
      await tester.pumpAndSettle();
      await enterPin(tester, testPin);
      await tester.pumpAndSettle();
      expect(done, isFalse);
      expect(find.textContaining('PIN belum tersimpan'), findsOneWidget);
      expect(await lock.hasPin(), isFalse);
    });
  });
}
