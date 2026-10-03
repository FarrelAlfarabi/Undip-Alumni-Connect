import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/screens/settings_screen.dart';
import 'package:undip_alumni_connect/settings/app_settings.dart';
import 'package:undip_alumni_connect/theme.dart';

import 'support/fake_lock.dart';

Map<String, dynamic> user({bool subscribed = false}) => {
  'id': 'p1',
  'name': 'Ahmad Ramadhan',
  'email': testEmail,
  'nim': '21120120130001',
  'faculty': 'Engineering',
  'verification_status': 'verified',
  'subscription_status': subscribed ? 'subscribed' : 'free',
};

Future<void> pumpSettings(
  WidgetTester tester, {
  required ValueNotifier<Map<String, dynamic>> currentUser,
  required AppSettings settings,
  required LockService lock,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.themeMode,
        home: SettingsScreen(
          currentUser: currentUser,
          settings: settings,
          lock: lock,
          signOutDestination: () => const Scaffold(body: Text('VERIFY')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AppSettings', () {
    test('defaults to system theme', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await AppSettings.load();
      expect(s.themeMode, ThemeMode.system);
    });

    test('saves the theme and reads it back', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await AppSettings.load();
      await s.setThemeMode(ThemeMode.dark);
      final again = await AppSettings.load();
      expect(again.themeMode, ThemeMode.dark);
    });

    test('ignores an unknown saved value', () async {
      SharedPreferences.setMockInitialValues({AppSettings.themeKey: 'purple'});
      final s = await AppSettings.load();
      expect(s.themeMode, ThemeMode.system);
    });
  });

  group('SettingsScreen', () {
    testWidgets(
      'shows account and a free subscription with a Subscribe button',
      (tester) async {
        await pumpSettings(
          tester,
          currentUser: ValueNotifier(user()),
          settings: AppSettings.inMemory(),
          lock: makeLock(),
        );
        expect(find.text('Ahmad Ramadhan'), findsOneWidget);
        expect(find.text('Verified alumni'), findsOneWidget);
        expect(find.byKey(const Key('plan-name')), findsOneWidget);
        expect(find.text('Free plan'), findsOneWidget);
        expect(find.byKey(const Key('subscribe-button')), findsOneWidget);
      },
    );

    testWidgets('shows an active subscription and no Subscribe button', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user(subscribed: true)),
        settings: AppSettings.inMemory(),
        lock: makeLock(),
      );
      expect(find.text('Annual plan'), findsOneWidget);
      expect(find.text('Subscribed'), findsOneWidget);
      expect(find.byKey(const Key('subscribe-button')), findsNothing);
      expect(find.byKey(const Key('subscription-note')), findsOneWidget);
    });

    testWidgets('reacts when the shared user becomes subscribed', (
      tester,
    ) async {
      final notifier = ValueNotifier(user());
      await pumpSettings(
        tester,
        currentUser: notifier,
        settings: AppSettings.inMemory(),
        lock: makeLock(),
      );
      expect(find.text('Free plan'), findsOneWidget);
      notifier.value = user(subscribed: true);
      await tester.pump();
      expect(find.text('Annual plan'), findsOneWidget);
    });

    testWidgets('Subscribe opens the subscribe screen', (tester) async {
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user()),
        settings: AppSettings.inMemory(),
        lock: makeLock(),
      );
      await tester.tap(find.byKey(const Key('subscribe-button')));
      await tester.pumpAndSettle();
      expect(find.text('Subscribe Now (Demo)'), findsOneWidget);
    });

    testWidgets('theme selector changes the app theme', (tester) async {
      final settings = AppSettings.inMemory();
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user()),
        settings: settings,
        lock: makeLock(),
      );
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(settings.themeMode, ThemeMode.dark);
      final brightness = Theme.of(tester.element(find.byType(SettingsScreen)))
          .brightness;
      expect(brightness, Brightness.dark);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(settings.themeMode, ThemeMode.light);
    });

    testWidgets('security section is hidden when the lock is disabled', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user()),
        settings: AppSettings.inMemory(),
        lock: makeLock(enabled: false),
      );
      expect(find.byKey(const Key('pin-tile')), findsNothing);
    });

    testWidgets('offers to set a PIN when none exists', (tester) async {
      final lock = await makeRememberedLock(withPin: false);
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user()),
        settings: AppSettings.inMemory(),
        lock: lock,
      );
      expect(find.text('Set a PIN'), findsOneWidget);
      expect(find.byKey(const Key('biometrics-switch')), findsNothing);
    });

    testWidgets('changing the PIN needs the current PIN first', (tester) async {
      final lock = await makeRememberedLock();
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user()),
        settings: AppSettings.inMemory(),
        lock: lock,
      );
      await tester.tap(find.byKey(const Key('pin-tile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-pin')), findsOneWidget);

      await enterPin(tester, '111222'); // wrong
      expect(find.byKey(const Key('confirm-pin-error')), findsOneWidget);
      expect(find.byKey(const Key('pin-setup')), findsNothing);

      await enterPin(tester, testPin);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pin-setup')), findsOneWidget);

      await enterPin(tester, '735190');
      await enterPin(tester, '735190');
      await tester.pumpAndSettle();
      expect(find.text('PIN changed.'), findsOneWidget);
      expect(await lock.checkPin('735190'), isA<PinOk>());
    });

    testWidgets('cancelling PIN change keeps the old PIN', (tester) async {
      final lock = await makeRememberedLock();
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user()),
        settings: AppSettings.inMemory(),
        lock: lock,
      );
      await tester.tap(find.byKey(const Key('pin-tile')));
      await tester.pumpAndSettle();
      await enterPin(tester, testPin);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pin-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pin-tile')), findsOneWidget);
      expect(await lock.checkPin(testPin), isA<PinOk>());
    });

    testWidgets('biometrics switch appears and turns on after a good scan', (
      tester,
    ) async {
      final lock = await makeRememberedLock(bio: FakeBiometrics());
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user()),
        settings: AppSettings.inMemory(),
        lock: lock,
      );
      expect(await lock.biometricsEnabled(), isFalse);
      await tester.tap(find.byKey(const Key('biometrics-switch')));
      await tester.pumpAndSettle();
      expect(await lock.biometricsEnabled(), isTrue);
    });

    testWidgets('sign out asks first, then clears this device', (tester) async {
      final store = MemoryLockStore();
      final lock = await makeRememberedLock(store: store);
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user()),
        settings: AppSettings.inMemory(),
        lock: lock,
      );
      await tester.ensureVisible(find.byKey(const Key('sign-out')));
      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('VERIFY'), findsNothing);
      expect(store.data, isNotEmpty);

      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-sign-out')));
      await tester.pumpAndSettle();
      expect(find.text('VERIFY'), findsOneWidget);
      expect(store.data, isEmpty);
    });

    testWidgets('no overflow at 320 px wide', (tester) async {
      await pumpSettings(
        tester,
        currentUser: ValueNotifier(user()),
        settings: AppSettings.inMemory(),
        lock: await makeRememberedLock(bio: FakeBiometrics()),
      );
      tester.view.physicalSize = const Size(320, 1600);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
