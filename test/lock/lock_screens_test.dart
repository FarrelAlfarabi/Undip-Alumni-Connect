import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/app_entry.dart';
import 'package:undip_alumni_connect/lock/biometrics.dart';
import 'package:undip_alumni_connect/lock/lock_config.dart';
import 'package:undip_alumni_connect/lock/lock_overlay.dart';
import 'package:undip_alumni_connect/lock/lock_screen.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/lock/pin_setup_screen.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';

import '../support/fake_lock.dart';

Widget appHome(Map<String, dynamic> profile) =>
    Scaffold(body: Text('APP for ${profile['name']}'));

Future<void> pumpEntry(
  WidgetTester tester,
  LockService lock, {
  ProfileFetcher? fetch,
  FakeClock? clock,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AppEntry(
        lock: lock,
        fetchProfile: fetch ?? (id) async => testProfile(),
        homeBuilder: appHome,
        clock: clock?.call ?? DateTime.now,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('entry: lock screen vs Welcome', () {
    testWidgets('new user sees the Welcome screen', (tester) async {
      await pumpEntry(tester, makeLock());
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.byKey(const Key('lock-screen')), findsNothing);
    });

    testWidgets('remembered user sees the lock screen, not Welcome', (
      tester,
    ) async {
      await pumpEntry(tester, await makeRememberedLock());
      expect(find.byKey(const Key('lock-screen')), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Welcome back, Ahmad'), findsOneWidget);
      expect(find.text('LINGKARAN'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget); // initials avatar
      expect(find.byKey(const Key('pin-5')), findsOneWidget);
      expect(find.text('Forgot PIN? Verify again'), findsOneWidget);
      expect(find.text('Not you? Switch account'), findsOneWidget);
    });

    testWidgets('web (lock disabled) always shows Welcome', (tester) async {
      final store = MemoryLockStore()
        ..data['lingkaran.lock.v1.profile_id'] = 'p1';
      await pumpEntry(tester, makeLock(store: store, enabled: false));
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('the lock screen never shows the full email', (tester) async {
      await pumpEntry(tester, await makeRememberedLock());
      expect(find.text('a***@example.com'), findsOneWidget);
      expect(find.textContaining(testEmail), findsNothing);
      expect(find.textContaining('ahmad.ramadhan'), findsNothing);
    });

    testWidgets('unreadable secure storage behaves like a new user', (
      tester,
    ) async {
      final lock = _ThrowingLock();
      await pumpEntry(tester, lock);
      expect(find.text('Get Started'), findsOneWidget);
    });
  });

  group('unlocking', () {
    testWidgets('correct PIN fetches the profile and enters the app', (
      tester,
    ) async {
      final lock = await makeRememberedLock();
      await pumpEntry(tester, lock);
      await enterPin(tester, testPin);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      expect(lock.sessionActive, isTrue);
    });

    testWidgets(
      'profile no longer exists: local data cleared, Welcome + message',
      (tester) async {
        final store = MemoryLockStore();
        final lock = await makeRememberedLock(store: store);
        await pumpEntry(tester, lock, fetch: (_) async => null);
        await enterPin(tester, testPin);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Get Started'), findsOneWidget);
        expect(find.byKey(const Key('welcome-notice')), findsOneWidget);
        expect(store.data, isEmpty);
      },
    );

    testWidgets('fetch fails: local data cleared, Welcome + message', (
      tester,
    ) async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await pumpEntry(tester, lock, fetch: (_) async => throw Exception('net'));
      await enterPin(tester, testPin);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(kSignInFailedNotice), findsOneWidget);
      expect(find.textContaining('net'), findsNothing); // no raw error
      expect(store.data, isEmpty);
    });

    testWidgets('profile not verified counts as gone', (tester) async {
      final lock = await makeRememberedLock();
      await pumpEntry(
        tester,
        lock,
        fetch: (_) async => testProfile(status: 'pending'),
      );
      await enterPin(tester, testPin);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('welcome-notice')), findsOneWidget);
    });
  });

  group('wrong PINs', () {
    testWidgets(
      'shows remaining attempts, delays after the 3rd, wipes on the 5th',
      (tester) async {
        final clock = FakeClock();
        final store = MemoryLockStore();
        final lock = await makeRememberedLock(store: store, clock: clock);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var lockedOut = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: LockScreen(
              lock: lock,
              user: (await lock.load())!,
              clock: clock.call,
              onUnlocked: () async {},
              onSwitchAccount: () async {},
              onForgotPin: () async {},
              onLockedOut: () async => lockedOut++,
              onContinue: () async {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        await enterPin(tester, '000001');
        expect(find.textContaining('4 attempts left'), findsOneWidget);
        await enterPin(tester, '000002');
        expect(find.textContaining('3 attempts left'), findsOneWidget);
        await enterPin(tester, '000003');
        expect(find.textContaining('2 attempts left'), findsOneWidget);
        expect(find.textContaining('Try again in'), findsOneWidget);

        // The pad ignores taps during the delay.
        await tester.tap(find.byKey(const Key('pin-1')));
        await tester.pump();
        expect(await lock.attemptsLeft(), 2);

        clock.advance(kWrongPinDelay + const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 12));
        expect(find.textContaining('Try again in'), findsNothing);

        await enterPin(tester, '000004');
        expect(find.textContaining('1 attempt left'), findsOneWidget);
        clock.advance(kWrongPinDelay + const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 12));
        await enterPin(tester, '000005');
        expect(lockedOut, 1);
        expect(store.data, isEmpty);
      },
    );

    testWidgets(
      '5th wrong PIN inside the app entry returns to Welcome with a message',
      (tester) async {
        final clock = FakeClock();
        final store = MemoryLockStore();
        final lock = await makeRememberedLock(store: store, clock: clock);
        await pumpEntry(tester, lock, clock: clock);
        for (var i = 1; i <= kMaxPinAttempts; i++) {
          await enterPin(tester, '00000$i');
          clock.advance(kWrongPinDelay + const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 12));
        }
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Get Started'), findsOneWidget);
        expect(find.text(kTooManyPinsNotice), findsOneWidget);
        expect(store.data, isEmpty);
      },
    );
  });

  group('biometrics', () {
    testWidgets('no button when the device has none', (tester) async {
      await pumpEntry(tester, await makeRememberedLock());
      expect(find.byKey(const Key('pin-biometric')), findsNothing);
    });

    testWidgets('success unlocks without a PIN', (tester) async {
      final bio = FakeBiometrics();
      final lock = await makeRememberedLock(bio: bio);
      await lock.setBiometricsEnabled(true);
      await pumpEntry(tester, lock);
      await tester.pump(const Duration(milliseconds: 100));
      expect(bio.prompts, 1); // auto prompt on show
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
    });

    testWidgets('failure or cancel falls back to the PIN pad', (tester) async {
      for (final result in [
        BiometricResult.failed,
        BiometricResult.cancelled,
      ]) {
        final bio = FakeBiometrics(result: result);
        final lock = await makeRememberedLock(bio: bio);
        await lock.setBiometricsEnabled(true);
        await pumpEntry(tester, lock);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Use your PIN instead.'), findsOneWidget);
        expect(find.byKey(const Key('pin-1')), findsOneWidget);
        // The PIN still works.
        await enterPin(tester, testPin);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
      'tapping the button retries; failed tries do not use up PIN attempts',
      (tester) async {
        final bio = FakeBiometrics(result: BiometricResult.failed);
        final lock = await makeRememberedLock(bio: bio);
        await lock.setBiometricsEnabled(true);
        await pumpEntry(tester, lock);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const Key('pin-biometric')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(bio.prompts, 2);
        expect(await lock.attemptsLeft(), kMaxPinAttempts);
        bio.result = BiometricResult.success;
        await tester.tap(find.byKey(const Key('pin-biometric')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      },
    );
  });

  group('switch account and forgot PIN', () {
    for (final key in ['lock-switch', 'lock-forgot']) {
      testWidgets('$key clears local data and shows the first-time flow', (
        tester,
      ) async {
        final store = MemoryLockStore();
        final lock = await makeRememberedLock(store: store);
        await pumpEntry(tester, lock);
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Get Started'), findsOneWidget);
        expect(store.data, isEmpty);
        expect(await lock.load(), isNull);
      });
    }
  });

  group('skipped PIN', () {
    testWidgets('lock screen offers Continue that re-runs verification', (
      tester,
    ) async {
      final lock = await makeRememberedLock(withPin: false);
      await pumpEntry(tester, lock);
      expect(find.byKey(const Key('lock-continue')), findsOneWidget);
      expect(find.byKey(const Key('pin-1')), findsNothing);
      await tester.tap(find.byKey(const Key('lock-continue')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Verify Alumni Status'), findsOneWidget);
    });
  });

  group('first-time PIN setup', () {
    Future<void> pumpSetup(
      WidgetTester tester,
      LockService lock,
      List<int> done,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PinSetupScreen(lock: lock, onDone: (_) async => done.add(1)),
        ),
      );
      await tester.pump();
    }

    testWidgets('enter twice: PIN saved as a hash, then done', (tester) async {
      final store = MemoryLockStore();
      final lock = makeLock(store: store);
      final done = <int>[];
      await pumpSetup(tester, lock, done);
      await enterPin(tester, testPin);
      expect(find.text('Enter it again to confirm'), findsOneWidget);
      await enterPin(tester, testPin);
      await tester.pump(const Duration(milliseconds: 100));
      expect(done, [1]);
      expect(await lock.hasPin(), isTrue);
      expect(store.data.values.join().contains(testPin), isFalse);
    });

    testWidgets('mismatch starts over with a message', (tester) async {
      final lock = makeLock();
      final done = <int>[];
      await pumpSetup(tester, lock, done);
      await enterPin(tester, testPin);
      await enterPin(tester, '111222');
      expect(find.byKey(const Key('pin-setup-error')), findsOneWidget);
      expect(find.text('Create a 6-digit PIN'), findsOneWidget);
      expect(await lock.hasPin(), isFalse);
      expect(done, isEmpty);
    });

    testWidgets('rejects an obvious PIN', (tester) async {
      final lock = makeLock();
      await pumpSetup(tester, lock, []);
      await enterPin(tester, '111111');
      expect(find.byKey(const Key('pin-setup-error')), findsOneWidget);
      expect(find.text('Create a 6-digit PIN'), findsOneWidget);
    });

    testWidgets('skip leaves no PIN and continues', (tester) async {
      final lock = makeLock();
      final done = <int>[];
      await pumpSetup(tester, lock, done);
      await tester.tap(find.byKey(const Key('pin-skip')));
      await tester.pump();
      expect(done, [1]);
      expect(await lock.hasPin(), isFalse);
    });

    testWidgets(
      'offers biometrics when supported; turning on needs a real check',
      (tester) async {
        final bio = FakeBiometrics();
        final lock = makeLock(bio: bio);
        final done = <int>[];
        await pumpSetup(tester, lock, done);
        await enterPin(tester, testPin);
        await enterPin(tester, testPin);
        expect(find.text('Unlock with fingerprint or face?'), findsOneWidget);
        // A failed check does not turn it on.
        bio.result = BiometricResult.failed;
        await tester.tap(find.byKey(const Key('bio-enable')));
        await tester.pump(const Duration(milliseconds: 50));
        expect(await lock.biometricsEnabled(), isFalse);
        expect(done, isEmpty);
        bio.result = BiometricResult.success;
        await tester.tap(find.byKey(const Key('bio-enable')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        expect(await lock.biometricsEnabled(), isTrue);
        expect(done, [1]);
      },
    );

    testWidgets('"Not now" keeps biometrics off but the PIN stays', (
      tester,
    ) async {
      final lock = makeLock(bio: FakeBiometrics());
      final done = <int>[];
      await pumpSetup(tester, lock, done);
      await enterPin(tester, testPin);
      await enterPin(tester, testPin);
      await tester.tap(find.byKey(const Key('bio-skip')));
      await tester.pump();
      expect(await lock.biometricsEnabled(), isFalse);
      expect(await lock.hasPin(), isTrue);
      expect(done, [1]);
    });
  });

  group('after verification', () {
    testWidgets('remembers the person, offers a PIN, then enters the app', (
      tester,
    ) async {
      final store = MemoryLockStore();
      final lock = makeLock(store: store);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: VerificationScreen(
            lock: lock,
            verifyEmail: (email) async => testProfile(),
            homeBuilder: appHome,
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), testEmail);
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('pin-setup')), findsOneWidget);
      expect((await lock.load())!.profileId, 'p1');
      expect(store.data.values.join().contains(testEmail), isFalse);

      await tester.tap(find.byKey(const Key('pin-skip')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      expect(lock.sessionActive, isTrue);
    });

    testWidgets('web (lock disabled): straight into the app, nothing stored', (
      tester,
    ) async {
      final store = MemoryLockStore();
      final lock = makeLock(store: store, enabled: false);
      await tester.pumpWidget(
        MaterialApp(
          home: VerificationScreen(
            lock: lock,
            verifyEmail: (email) async => testProfile(),
            homeBuilder: appHome,
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), testEmail);
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('APP for Ahmad Ramadhan'), findsOneWidget);
      expect(store.data, isEmpty);
    });
  });

  group('background timeout (fake clock)', () {
    Future<void> pumpOverlay(
      WidgetTester tester,
      LockService lock,
      FakeClock clock,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          builder: (context, child) => LockOverlay(
            lock: lock,
            navigatorKey: key,
            clock: clock.call,
            child: child!,
          ),
          home: const Scaffold(body: Text('THE APP')),
        ),
      );
      await tester.pump();
    }

    Future<void> background(
      WidgetTester tester,
      FakeClock clock,
      Duration away,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.advance(away);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('default timeout is 5 minutes', (tester) async {
      expect(kLockAfterBackground, const Duration(minutes: 5));
    });

    testWidgets('short absence: no lock', (tester) async {
      final clock = FakeClock();
      final lock = await makeRememberedLock(clock: clock)
        ..sessionActive = true;
      await pumpOverlay(tester, lock, clock);
      await background(tester, clock, const Duration(minutes: 4));
      expect(find.byKey(const Key('lock-screen')), findsNothing);
      expect(find.text('THE APP'), findsOneWidget);
    });

    testWidgets('long absence: lock screen covers the app; PIN unlocks it', (
      tester,
    ) async {
      final clock = FakeClock();
      final lock = await makeRememberedLock(clock: clock)
        ..sessionActive = true;
      await pumpOverlay(tester, lock, clock);
      await background(tester, clock, const Duration(minutes: 6));
      expect(find.byKey(const Key('lock-screen')), findsOneWidget);
      expect(find.text('THE APP'), findsNothing); // hidden (offstage)

      await enterPin(tester, testPin);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('lock-screen')), findsNothing);
      expect(find.text('THE APP'), findsOneWidget);
    });

    testWidgets('no PIN set: never locks', (tester) async {
      final clock = FakeClock();
      final lock = await makeRememberedLock(clock: clock, withPin: false)
        ..sessionActive = true;
      await pumpOverlay(tester, lock, clock);
      await background(tester, clock, const Duration(hours: 2));
      expect(find.byKey(const Key('lock-screen')), findsNothing);
    });

    testWidgets('nobody signed in yet: never locks', (tester) async {
      final clock = FakeClock();
      final lock = await makeRememberedLock(clock: clock);
      await pumpOverlay(tester, lock, clock);
      await background(tester, clock, const Duration(hours: 2));
      expect(find.byKey(const Key('lock-screen')), findsNothing);
    });

    testWidgets('lock disabled (web): never locks', (tester) async {
      final clock = FakeClock();
      final lock = makeLock(clock: clock, enabled: false)..sessionActive = true;
      await pumpOverlay(tester, lock, clock);
      await background(tester, clock, const Duration(hours: 2));
      expect(find.byKey(const Key('lock-screen')), findsNothing);
    });

    testWidgets(
      'switch account on the relock screen wipes data and shows Welcome',
      (tester) async {
        final clock = FakeClock();
        final store = MemoryLockStore();
        final lock = await makeRememberedLock(store: store, clock: clock)
          ..sessionActive = true;
        await pumpOverlay(tester, lock, clock);
        await background(tester, clock, const Duration(minutes: 6));
        await tester.ensureVisible(find.byKey(const Key('lock-switch')));
        await tester.tap(find.byKey(const Key('lock-switch')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Get Started'), findsOneWidget);
        expect(store.data, isEmpty);
        expect(lock.sessionActive, isFalse);
      },
    );
  });
}

/// A service whose storage always fails.
class _ThrowingLock extends LockService {
  _ThrowingLock()
    : super(
        store: MemoryLockStore(),
        biometrics: FakeBiometrics(available: false),
      );

  @override
  Future<RememberedUser?> load() async => throw Exception('keystore broken');
}
