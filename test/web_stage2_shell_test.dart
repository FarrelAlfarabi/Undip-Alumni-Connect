import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/platform/app_location.dart';
import 'package:undip_alumni_connect/screens/home_shell.dart';

import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

const _profile = {'id': 'me', 'name': 'Ahmad Ramadhan', 'email': 'a@x.com'};

Future<void> _pump(WidgetTester t, double width, {bool chat = false}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: HomeShell(
        profile: _profile,
        chat: chat,
        pages: fakePages(),
        homeApi: FakeHomeApi(announcements: [announcementMap(1)]),
        marketplaceRepository: MarketplaceRepository(FakeApi()),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Finder _side(String label) => find.descendant(
  of: find.byKey(const Key('side-nav')),
  matching: find.text(label),
);

void main() {
  late List<String> reported;

  setUp(() {
    reported = [];
    AppLocation.reporter = reported.add;
    AppLocation.initialPath = null;
  });
  tearDown(AppLocation.reset);

  group('paths', () {
    test('every tab and Explore segment has its own path', () {
      expect(AppLocation.pathFor(ShellPlace.home), '/');
      expect(AppLocation.pathFor(ShellPlace.members), '/members');
      expect(AppLocation.pathFor(ShellPlace.explore), '/explore');
      expect(
        AppLocation.pathFor(ShellPlace.explore, segment: 1),
        '/explore/businesses',
      );
      expect(
        AppLocation.pathFor(ShellPlace.explore, segment: 2),
        '/explore/jobs',
      );
      expect(AppLocation.pathFor(ShellPlace.chat), '/chat');
      expect(AppLocation.pathFor(ShellPlace.profile), '/profile');
    });

    test('paths are read back, unknown ones open Home', () {
      expect(AppLocation.parse('/'), (ShellPlace.home, 0));
      expect(AppLocation.parse('/home'), (ShellPlace.home, 0));
      expect(AppLocation.parse('/members'), (ShellPlace.members, 0));
      expect(AppLocation.parse('/members/'), (ShellPlace.members, 0));
      expect(AppLocation.parse('/explore'), (ShellPlace.explore, 0));
      expect(AppLocation.parse('/explore/businesses'), (ShellPlace.explore, 1));
      expect(AppLocation.parse('/explore/jobs'), (ShellPlace.explore, 2));
      expect(AppLocation.parse('/explore/xyz'), (ShellPlace.explore, 0));
      expect(AppLocation.parse('/profile?x=1'), (ShellPlace.profile, 0));
      expect(AppLocation.parse('/chat'), (ShellPlace.chat, 0));
      expect(AppLocation.parse('/nothing'), (ShellPlace.home, 0));
      expect(AppLocation.parse(''), (ShellPlace.home, 0));
    });
  });

  group('layout by width', () {
    testWidgets('390: bottom bar, no side nav, full width', (t) async {
      await _pump(t, 390);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('side-nav')), findsNothing);
      expect(t.getSize(find.byKey(const Key('shell-content'))).width, 390);
      expect(t.takeException(), isNull);
    });

    testWidgets('768: bottom bar, content centred at 720', (t) async {
      await _pump(t, 768);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('side-nav')), findsNothing);
      final box = find.byKey(const Key('shell-content'));
      expect(t.getSize(box).width, 720);
      expect(t.getTopLeft(box).dx, 24);
      expect(t.takeException(), isNull);
    });

    testWidgets('1280: side nav on the left, no bottom bar', (t) async {
      await _pump(t, 1280);
      expect(find.byType(NavigationBar), findsNothing);
      final nav = find.byKey(const Key('side-nav'));
      expect(nav, findsOneWidget);
      expect(t.getTopLeft(nav).dx, 0);
      for (final label in ['Home', 'Members', 'Explore', 'Profile']) {
        expect(_side(label), findsOneWidget, reason: label);
      }
      expect(_side('Chat'), findsNothing);
      // Content is a centred column no wider than 960 next to the nav.
      final box = find.byKey(const Key('shell-content'));
      final navRight = t.getTopRight(nav).dx;
      expect(t.getSize(box).width, 960);
      final left = t.getTopLeft(box).dx - navRight;
      final right = 1280 - t.getTopRight(box).dx;
      expect((left - right).abs(), lessThan(1));
      expect(t.takeException(), isNull);
    });

    testWidgets('1280: side nav switches tabs', (t) async {
      await _pump(t, 1280);
      expect(find.text('Halo, Ahmad'), findsOneWidget);
      await t.tap(_side('Members'));
      await t.pumpAndSettle();
      expect(find.text('Directory'), findsOneWidget);
      await t.tap(_side('Profile'));
      await t.pumpAndSettle();
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Halo, Ahmad'), findsNothing);
    });

    testWidgets('1280 with chat on: Chat is in the side nav', (t) async {
      await _pump(t, 1280, chat: true);
      expect(_side('Chat'), findsOneWidget);
    });

    testWidgets('resizing from desktop to phone keeps the tab', (t) async {
      await _pump(t, 1280);
      await t.tap(_side('Members'));
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(390, 844);
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Directory'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('the address bar follows the screen', () {
    testWidgets('switching tabs reports each path', (t) async {
      await _pump(t, 1280);
      await t.tap(_side('Members'));
      await t.pumpAndSettle();
      await t.tap(_side('Explore'));
      await t.pumpAndSettle();
      await t.tap(_side('Profile'));
      await t.pumpAndSettle();
      await t.tap(_side('Home'));
      await t.pumpAndSettle();
      expect(reported, ['/', '/members', '/explore', '/profile', '/']);
    });

    testWidgets('changing the Explore segment reports its path', (t) async {
      await _pump(t, 390);
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Explore'),
        ),
      );
      await t.pumpAndSettle();
      final state = t.state<State<HomeShell>>(find.byType(HomeShell));
      (state as dynamic).debugSetMarketSegment(2);
      await t.pumpAndSettle();
      expect(reported.last, '/explore/jobs');
    });

    testWidgets('a refresh on /members opens Members', (t) async {
      AppLocation.initialPath = '/members';
      await _pump(t, 1280);
      expect(find.text('Directory'), findsOneWidget);
      expect(find.text('Halo, Ahmad'), findsNothing);
    });

    testWidgets('a refresh on /explore/businesses opens that segment', (
      t,
    ) async {
      AppLocation.initialPath = '/explore/businesses';
      await _pump(t, 390);
      expect(find.text('Market Businesses'), findsOneWidget);
    });

    testWidgets('a refresh on /chat with chat off opens Home', (t) async {
      AppLocation.initialPath = '/chat';
      await _pump(t, 390);
      expect(find.text('Halo, Ahmad'), findsOneWidget);
    });

    testWidgets('the start path is used once, a later shell opens Home', (
      t,
    ) async {
      AppLocation.initialPath = '/profile';
      await _pump(t, 390);
      expect(find.text('Halo, Ahmad'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await _pump(t, 390);
      expect(find.text('Halo, Ahmad'), findsOneWidget);
    });

    testWidgets('leaving the shell puts the address back to /', (t) async {
      await _pump(t, 390);
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Members'),
        ),
      );
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      expect(reported.last, '/');
    });

    testWidgets('back from a tab returns Home and reports /', (t) async {
      await _pump(t, 1280);
      await t.tap(_side('Members'));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Halo, Ahmad'), findsOneWidget);
      expect(reported.last, '/');
    });
  });

  group('web setup', () {
    test('main uses clean paths and ignores the path for the first route', () {
      final src = File('lib/main.dart').readAsStringSync();
      expect(src, contains('usePathUrlStrategy()'));
      expect(src, contains('onGenerateInitialRoutes'));
      expect(src, contains('AppLocation.initialPath'));
    });

    test('Vercel sends every path to index.html', () {
      final src = File('vercel.json').readAsStringSync();
      expect(src, contains('"rewrites"'));
      expect(src, contains('"destination": "/index.html"'));
    });

    test('old Vercel host redirects to lingkaran-ikafe, keeping the path', () {
      final json = jsonDecode(File('vercel.json').readAsStringSync()) as Map;
      final redirects = (json['redirects'] as List).cast<Map>();
      expect(redirects, hasLength(1));
      final r = redirects.single;
      expect(r['source'], '/(.*)');
      expect(r['destination'], 'https://lingkaran-ikafe.vercel.app/\$1');
      expect(r['permanent'], isFalse);
      final has = (r['has'] as List).single as Map;
      expect(has['type'], 'host');
      expect(has['value'], 'undip-alumni-connect.vercel.app');
    });
  });
}
