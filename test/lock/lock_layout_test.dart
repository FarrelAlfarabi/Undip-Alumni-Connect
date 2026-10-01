import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_config.dart';
import 'package:undip_alumni_connect/lock/lock_screen.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';
import 'package:undip_alumni_connect/lock/pin_setup_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';
import 'package:undip_alumni_connect/theme.dart';

import '../support/fake_lock.dart';

/// Phone-width layout checks: no overflow at small sizes and large text.
void main() {
  const sizes = [Size(320, 568), Size(360, 640), Size(390, 844)];

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget child, {
    double textScale = 1.4,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  for (final size in sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('lock screen with fingerprint key, $label', (tester) async {
      final bio = FakeBiometrics();
      final lock = await makeRememberedLock(bio: bio);
      await lock.setBiometricsEnabled(true);
      await pumpAt(
        tester,
        size,
        LockScreen(
          lock: lock,
          user: (await lock.load())!,
          autoBiometric: false,
          onUnlocked: () async {},
          onSwitchAccount: () async {},
          onForgotPin: () async {},
          onLockedOut: () async {},
          onContinue: () async {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('pin-biometric')), findsOneWidget);
    });

    testWidgets('lock screen during a wrong-PIN wait, $label', (tester) async {
      final clock = FakeClock();
      final lock = await makeRememberedLock(clock: clock);
      await pumpAt(
        tester,
        size,
        LockScreen(
          lock: lock,
          user: (await lock.load())!,
          clock: clock.call,
          onUnlocked: () async {},
          onSwitchAccount: () async {},
          onForgotPin: () async {},
          onLockedOut: () async {},
          onContinue: () async {},
        ),
      );
      for (var i = 0; i < kDelayAfterAttempts; i++) {
        await enterPin(tester, '00000$i');
      }
      expect(find.textContaining('Try again in'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Let the countdown timer finish so no timer is left pending.
      clock.advance(kWrongPinDelay + const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('lock screen with no PIN (Continue), $label', (tester) async {
      final lock = await makeRememberedLock(withPin: false);
      await pumpAt(
        tester,
        size,
        LockScreen(
          lock: lock,
          user: (await lock.load())!,
          onUnlocked: () async {},
          onSwitchAccount: () async {},
          onForgotPin: () async {},
          onLockedOut: () async {},
          onContinue: () async {},
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('PIN setup with an error message, $label', (tester) async {
      await pumpAt(
        tester,
        size,
        PinSetupScreen(lock: makeLock(), onDone: (_) async {}),
      );
      await enterPin(tester, '111111');
      expect(find.byKey(const Key('pin-setup-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Welcome with a notice, $label', (tester) async {
      await pumpAt(
        tester,
        size,
        const WelcomeScreen(
          notice:
              "We couldn't sign you in on this device. Please verify again.",
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a long display name does not overflow the lock screen', (
    tester,
  ) async {
    final store = MemoryLockStore();
    final lock = makeLock(store: store);
    await lock.remember(
      profileId: 'p1',
      displayName: 'Muhammad Abdurrahman Al-Farabi bin Ahmad Ramadhan Saleh',
      email: 'a.very.long.address.indeed@subdomain.example.co.id',
    );
    await lock.setPin(testPin);
    await pumpAt(
      tester,
      const Size(320, 568),
      LockScreen(
        lock: lock,
        user: (await lock.load())!,
        autoBiometric: false,
        onUnlocked: () async {},
        onSwitchAccount: () async {},
        onForgotPin: () async {},
        onLockedOut: () async {},
        onContinue: () async {},
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
