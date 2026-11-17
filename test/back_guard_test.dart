import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/lock/app_entry.dart';
import 'package:undip_alumni_connect/lock/lock_overlay.dart';
import 'package:undip_alumni_connect/lock/pin_setup_screen.dart';
import 'package:undip_alumni_connect/nav/back_guard.dart';
import 'package:undip_alumni_connect/policy/consent_screen.dart';
import 'package:undip_alumni_connect/screens/first_login_profile_screen.dart';
import 'package:undip_alumni_connect/screens/home_shell.dart';
import 'package:undip_alumni_connect/screens/returning_screen.dart';
import 'package:undip_alumni_connect/screens/verification_screen.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';

import 'support/fake_home.dart';
import 'support/fake_lock.dart';
import 'support/fake_marketplace_api.dart';

/// One Back rule for the whole app (see BackGuard). These tests fail when a
/// screen's Back would close the app on the first press, so a new screen
/// cannot bring the problem back.

int exits = 0;
late DateTime now;

void setUpGuard({bool web = false}) {
  BackGuard.reset();
  exits = 0;
  now = DateTime(2026, 11, 17, 12);
  BackGuard.exitApp = () => exits++;
  BackGuard.clock = () => now;
  BackGuard.web = web;
}

/// Cancels the exit hint's timer, which would otherwise outlive the test.
void testGuard(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      BackGuard.reset();
    });

Future<void> pumpRoot(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      onGenerateInitialRoutes: (_) => [AppRoute(builder: (_) => screen)],
      onGenerateRoute: (_) => AppRoute(builder: (_) => screen),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
}

/// Every screen that can be the first route of the app: before sign in, and
/// Home after it.
final Map<String, Widget Function()> rootScreens = {
  'Welcome': () => const WelcomeScreen(),
  'Returning (web)': () =>
      ReturningScreen(name: 'Ahmad', onNotYou: () async {}),
  'Verification': () => const VerificationScreen(),
  'PIN setup': () => PinSetupScreen(lock: makeLock(), onDone: (_) async {}),
  'Consent': () => ConsentScreen(
    profile: testProfile(policyVersion: null),
    onAccepted: (_, _) {},
  ),
  'First login profile': () =>
      FirstLoginProfileScreen(profile: testProfile(), onDone: (_, _) {}),
  'Home shell': () => HomeShell(
    profile: const {'id': 'me', 'name': 'Ahmad', 'email': 'a@example.com'},
    chat: false,
    pages: fakePages(),
    homeApi: FakeHomeApi(announcements: [announcementMap(1)]),
    marketplaceRepository: MarketplaceRepository(FakeApi()),
  ),
};

void main() {
  setUp(setUpGuard);

  group('source rules', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.replaceAll('\\', '/').contains('lib/nav/'));

    test('every screen route is an AppRoute', () {
      final bad = [
        for (final f in files)
          if (RegExp(r'MaterialPageRoute|CupertinoPageRoute|PageRouteBuilder')
              .hasMatch(f.readAsStringSync()))
            f.path,
      ];
      expect(bad, isEmpty, reason: 'use AppRoute (lib/nav/back_guard.dart)');
    });

    test('nothing but BackGuard exits the app', () {
      final bad = [
        for (final f in files)
          if (RegExp(r'SystemNavigator\.pop|\bexit\(|SystemChannels\.platform')
              .hasMatch(f.readAsStringSync()))
            f.path,
      ];
      expect(bad, isEmpty, reason: 'use BackGuard.rootBack');
    });
  });

  group('first Back never exits (phone)', () {
    for (final entry in rootScreens.entries) {
      testGuard(entry.key, (tester) async {
        await pumpRoot(tester, entry.value());
        await back(tester);
        expect(exits, 0, reason: 'first Back on ${entry.key}');
        expect(find.byKey(const Key('exit-hint')), findsOneWidget);
        // Second Back inside the window leaves.
        now = now.add(const Duration(seconds: 1));
        await back(tester);
        expect(exits, 1);
      });
    }

    testGuard('a slow second Back only shows the hint again', (tester) async {
      await pumpRoot(tester, const WelcomeScreen());
      await back(tester);
      now = now.add(const Duration(seconds: 5));
      await back(tester);
      expect(exits, 0);
      expect(find.byKey(const Key('exit-hint')), findsOneWidget);
      await tester.pump(BackGuard.window);
    });

    testGuard('lock screen via AppEntry', (tester) async {
      await pumpRoot(
        tester,
        AppEntry(
          lock: await makeRememberedLock(),
          fetchProfile: (_) async => testProfile(),
        ),
      );
      expect(find.byKey(const Key('lock-screen')), findsOneWidget);
      await back(tester);
      expect(exits, 0);
      expect(find.byKey(const Key('lock-screen')), findsOneWidget);
    });
  });

  group('web: Back never leaves the app', () {
    for (final entry in rootScreens.entries) {
      testGuard(entry.key, (tester) async {
        setUpGuard(web: true);
        await pumpRoot(tester, entry.value());
        await back(tester);
        await back(tester);
        expect(exits, 0);
      });
    }
  });

  group('screens above the root', () {
    testGuard('Back pops a pushed screen and a dialog first', (tester) async {
      await pumpRoot(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                AppRoute(builder: (_) => const Scaffold(body: Text('PUSHED'))),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('PUSHED'), findsOneWidget);
      await back(tester);
      await tester.pumpAndSettle();
      expect(find.text('PUSHED'), findsNothing);
      expect(exits, 0);
      expect(find.byKey(const Key('exit-hint')), findsNothing);
    });

    testGuard('screens after pushAndRemoveUntil are still guarded', (
      tester,
    ) async {
      await pumpRoot(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              AppRoute(builder: (_) => const Scaffold(body: Text('NEW ROOT'))),
              (_) => false,
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await back(tester);
      expect(exits, 0);
      expect(find.text('NEW ROOT'), findsOneWidget);
    });
  });

  group('lock overlay', () {
    testGuard('Back while locked does not pop the hidden screen', (
      tester,
    ) async {
      final lock = await makeRememberedLock();
      lock.sessionActive = true;
      final clock = FakeClock();
      final key = GlobalKey<NavigatorState>();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          builder: (context, child) => LockOverlay(
            lock: lock,
            navigatorKey: key,
            clock: clock.call,
            timeout: const Duration(seconds: 1),
            child: child!,
          ),
          onGenerateRoute: (_) => AppRoute(builder: (_) => const SizedBox()),
          onGenerateInitialRoutes: (_) => [
            AppRoute(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(c).push(
                    AppRoute(
                      builder: (_) => const Scaffold(body: Text('INNER')),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.advance(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(BackGuard.locked.value, isTrue);
      await back(tester);
      await tester.pump();
      expect(exits, 0);
      expect(
        find.text('INNER', skipOffstage: false),
        findsOneWidget,
        reason: 'the hidden screen stays where it was',
      );
    });
  });
}
