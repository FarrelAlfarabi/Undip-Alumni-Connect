import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/policy_config.dart';
import 'package:undip_alumni_connect/lock/app_entry.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/lock/session.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';
import 'package:undip_alumni_connect/util/friendly_error.dart';

import '../support/fake_lock.dart';

Widget appHome(Map<String, dynamic> profile) =>
    Scaffold(body: Text('APP for ${profile['name']}'));

Future<void> verifyAs(
  WidgetTester tester,
  LockService lock,
  Map<String, dynamic> profile,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(), // a fresh navigator, not the signed-out one
      home: VerificationScreen(
        lock: lock,
        verifyEmail: (email) async => profile,
        homeBuilder: appHome,
      ),
    ),
  );
  await tester.enterText(find.byType(TextFormField), testEmail);
  await tester.tap(find.text('Verify'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> signOut(WidgetTester tester, LockService lock) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                signOutTo(context, const Text('VERIFY'), lock: lock),
            child: const Text('SIGN OUT'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('SIGN OUT'));
  await tester.pumpAndSettle();
}

void main() {
  group('PIN survives sign out', () {
    test(
      'signOut forgets the person but keeps the PIN and fingerprint',
      () async {
        final store = MemoryLockStore();
        final lock = await makeRememberedLock(store: store);
        await lock.setBiometricsEnabled(true);
        await lock.signOut();
        expect(await lock.load(), isNull);
        expect(await lock.hasPin(), isTrue);
        expect(lock.sessionActive, isFalse);
      },
    );

    test('same profile verifies again: PIN still there', () async {
      final lock = await makeRememberedLock();
      await lock.signOut();
      await lock.remember(
        profileId: 'p1',
        displayName: 'Ahmad Ramadhan',
        email: testEmail,
      );
      expect(await lock.hasPin(), isTrue);
      expect(await lock.checkPin(testPin), isA<PinOk>());
    });

    test('a different profile does NOT inherit the old PIN', () async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await lock.setBiometricsEnabled(true);
      await lock.signOut();
      await lock.remember(
        profileId: 'p2',
        displayName: 'Bunga',
        email: 'bunga@example.com',
      );
      expect(await lock.hasPin(), isFalse);
      expect(await lock.biometricsEnabled(), isFalse);
      expect(store.data.keys.any((k) => k.endsWith('pin_hash')), isFalse);
      expect((await lock.load())!.profileId, 'p2');
    });

    test('a PIN of unknown owner is dropped when someone verifies', () async {
      final store = MemoryLockStore()
        ..data['lingkaran.lock.v1.pin_hash'] = 'v1:legacy';
      final lock = makeLock(store: store);
      await lock.remember(profileId: 'p9', displayName: 'X', email: testEmail);
      expect(await lock.hasPin(), isFalse);
    });

    test(
      'an old install (PIN, no owner key) keeps its PIN for the same person',
      () async {
        final store = MemoryLockStore();
        final lock = await makeRememberedLock(store: store);
        store.data.remove(
          'lingkaran.lock.v1.owner_id',
        ); // as written before this fix
        await lock.remember(
          profileId: 'p1',
          displayName: 'Ahmad Ramadhan',
          email: testEmail,
        );
        expect(await lock.hasPin(), isTrue);
      },
    );

    test('clear() still wipes everything, owner included', () async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await lock.clear();
      expect(store.data, isEmpty);
    });

    testWidgets('widget flow: set PIN, sign out, verify again: no PIN setup', (
      tester,
    ) async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await signOut(tester, lock);
      expect(find.text('VERIFY'), findsOneWidget);
      await verifyAs(tester, lock, testProfile());
      expect(find.byKey(const Key('pin-setup')), findsNothing);
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
    });

    testWidgets(
      'widget flow: another profile on the same phone gets PIN setup',
      (tester) async {
        final store = MemoryLockStore();
        final lock = await makeRememberedLock(store: store);
        await signOut(tester, lock);
        await verifyAs(tester, lock, {
          'id': 'p2',
          'name': 'Bunga',
          'email': testEmail,
          'verification_status': 'verified',
          'policy_version': kPolicyVersion,
        });
        expect(find.byKey(const Key('pin-setup')), findsOneWidget);
      },
    );
  });

  group('network error while unlocking', () {
    Future<void> pump(
      WidgetTester tester,
      LockService lock,
      ProfileFetcher f,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AppEntry(lock: lock, fetchProfile: f, homeBuilder: appHome),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'keeps the PIN and the remembered person, shows a retry message',
      (tester) async {
        final store = MemoryLockStore();
        final lock = await makeRememberedLock(store: store);
        var fail = true;
        await pump(tester, lock, (_) async {
          if (fail) throw Exception('SocketException: Failed host lookup');
          return testProfile();
        });
        await enterPin(tester, testPin);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(kNetworkError), findsOneWidget);
        expect(find.byKey(const Key('lock-screen')), findsOneWidget);
        expect(await lock.hasPin(), isTrue);
        expect((await lock.load())!.profileId, 'p1');

        // Retry works once the network is back.
        fail = false;
        await tester.pump(const Duration(seconds: 5));
        await enterPin(tester, testPin);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      },
    );

    testWidgets('a profile that is really gone still wipes the device', (
      tester,
    ) async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await pump(tester, lock, (_) async => null);
      await enterPin(tester, testPin);
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.data, isEmpty);
      expect(find.byKey(const Key('welcome-notice')), findsOneWidget);
    });
  });
}
