import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/lock/session.dart';
import 'package:undip_alumni_connect/platform/app_location.dart';
import 'package:undip_alumni_connect/screens/home_shell.dart';
import 'package:undip_alumni_connect/widgets/brand_lockup.dart';

import 'support/fake_home.dart';
import 'support/fake_lock.dart';
import 'support/fake_marketplace_api.dart';

const _profile = {'id': 'me', 'name': 'Ahmad Ramadhan', 'email': 'a@x.com'};

Future<void> _pump(WidgetTester t, double width) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: HomeShell(
        profile: _profile,
        chat: false,
        pages: fakePages(),
        homeApi: FakeHomeApi(announcements: [announcementMap(1)]),
        marketplaceRepository: MarketplaceRepository(FakeApi()),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _openNotifications(WidgetTester t) async {
  await t.tap(find.byKey(const Key('home-notifications')));
  await t.pumpAndSettle();
  expect(find.text('Notifications'), findsWidgets);
}

Finder _side(String label) => find.descendant(
  of: find.byKey(const Key('side-nav')),
  matching: find.text(label),
);

void main() {
  setUp(() => AppLocation.reporter = (_) {});
  tearDown(AppLocation.reset);

  group('screens opened from a tab', () {
    testWidgets('1280: open inside the content column, side nav stays', (
      t,
    ) async {
      await _pump(t, 1280);
      await _openNotifications(t);
      expect(find.byKey(const Key('side-nav')), findsOneWidget);
      final page = find.text('PAGE Notifications');
      final box = find.byKey(const Key('shell-content'));
      expect(t.getTopLeft(page).dx, greaterThanOrEqualTo(t.getTopLeft(box).dx));
      expect(t.getTopRight(page).dx, lessThanOrEqualTo(t.getTopRight(box).dx));
      // It has a back arrow, and back returns to Home.
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('Halo, Ahmad'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('1280: browser back closes the screen first', (t) async {
      await _pump(t, 1280);
      await t.tap(_side('Members'));
      await t.pumpAndSettle();
      await t.tap(_side('Home'));
      await t.pumpAndSettle();
      await _openNotifications(t);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('PAGE Notifications'), findsNothing);
      expect(find.text('Halo, Ahmad'), findsOneWidget);
    });

    testWidgets('1280: a side nav tap closes the open screen', (t) async {
      await _pump(t, 1280);
      await _openNotifications(t);
      await t.tap(_side('Members'));
      await t.pumpAndSettle();
      expect(find.text('PAGE Notifications'), findsNothing);
      expect(find.text('Directory'), findsOneWidget);
      // Back on Home, the screen is not there any more.
      await t.tap(_side('Home'));
      await t.pumpAndSettle();
      expect(find.text('Halo, Ahmad'), findsOneWidget);
    });

    testWidgets('390: still covers the screen, no bottom bar, as before', (
      t,
    ) async {
      await _pump(t, 390);
      await _openNotifications(t);
      expect(find.byType(NavigationBar), findsNothing);
      expect(t.getSize(find.byType(Scaffold).last).width, 390);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('768: still covers the screen, as before', (t) async {
      await _pump(t, 768);
      await _openNotifications(t);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('logo', () {
    testWidgets('1280: shown once, in the side nav', (t) async {
      await _pump(t, 1280);
      expect(find.byType(BrandLockup), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('side-nav')),
          matching: find.byType(BrandLockup),
        ),
        findsOneWidget,
      );
    });

    testWidgets('390: in the Home bar, as before', (t) async {
      await _pump(t, 390);
      expect(find.byType(BrandLockup), findsOneWidget);
    });
  });

  testWidgets('signing out from a screen inside the shell replaces the app', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Text('OUTER'),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => signOutTo(context, const Text('OUT'), lock: makeLock()),
                      child: const Text('SIGN OUT'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await t.tap(find.text('SIGN OUT'));
    await t.pumpAndSettle();
    expect(find.text('OUT'), findsOneWidget);
    expect(find.text('OUTER'), findsNothing);
  });
}
