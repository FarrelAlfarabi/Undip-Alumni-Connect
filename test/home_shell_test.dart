import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/feature_flags.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/alumni_screen.dart';
import 'package:undip_alumni_connect/screens/home_pages.dart';
import 'package:undip_alumni_connect/screens/home_shell.dart';
import 'package:undip_alumni_connect/screens/job_board_screen.dart';
import 'package:undip_alumni_connect/screens/market_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_screen.dart';
import 'package:undip_alumni_connect/screens/announcements_screen.dart';
import 'package:undip_alumni_connect/screens/messages_list_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

const profile = {
  'id': 'me',
  'name': 'Ahmad Ramadhan',
  'email': 'a@example.com',
};

Future<void> pumpShell(
  WidgetTester tester, {
  HomePages? pages,
  List<int>? chatBuilds,
  List<ValueNotifier<Map<String, dynamic>>>? users,
  bool? chat,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HomeShell(
                    profile: profile,
                    chat: chat ?? chatEnabled,
                    pages:
                        pages ??
                        fakePages(users: users, chatBuilds: chatBuilds),
                    homeApi: FakeHomeApi(announcements: [announcementMap(1)]),
                    marketplaceRepository: MarketplaceRepository(FakeApi()),
                  ),
                ),
              ),
              child: const Text('OPEN SHELL'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN SHELL'));
  await tester.pumpAndSettle();
}

Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('chat is switched off for the beta', () {
    expect(chatEnabled, isFalse);
  });

  testWidgets('bottom navigation has Home, Directory, Market, Profile', (
    tester,
  ) async {
    await pumpShell(tester, chat: false);
    final destinations = tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    );
    expect(destinations.map((d) => d.label).toList(), [
      'Home',
      'Directory',
      'Market',
      'Profile',
    ]);
    expect(find.text('Chat'), findsNothing);
    // Lands on Home.
    expect(find.text('Hello, Ahmad'), findsOneWidget);
    // Profile is the last tab and still opens.
    await tapNav(tester, 'Profile');
    expect(find.text('PAGE Profile'), findsOneWidget);
  });

  testWidgets('switch on: Chat comes back between Market and Profile', (
    tester,
  ) async {
    await pumpShell(tester, chat: true);
    final destinations = tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    );
    expect(destinations.map((d) => d.label).toList(), [
      'Home',
      'Directory',
      'Market',
      'Chat',
      'Profile',
    ]);
  });

  group('back button', () {
    testWidgets('from any other tab, back returns to Home and stays in app', (
      tester,
    ) async {
      await pumpShell(tester, chat: true);
      for (final tab in ['Directory', 'Market', 'Chat', 'Profile']) {
        await tapNav(tester, tab);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(HomeShell), findsOneWidget, reason: 'from $tab');
        expect(find.text('Hello, Ahmad'), findsOneWidget, reason: 'from $tab');
      }
    });

    testWidgets('from Home, back leaves the shell', (tester) async {
      await pumpShell(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsNothing);
    });
  });

  testWidgets('every page gets the same shared currentUser notifier', (
    tester,
  ) async {
    final users = <ValueNotifier<Map<String, dynamic>>>[];
    await pumpShell(tester, users: users, chat: true);
    for (final tab in ['Directory', 'Market', 'Chat', 'Profile']) {
      await tapNav(tester, tab);
    }
    await tapNav(tester, 'Home');
    for (final tile in ['tile-jobs', 'tile-nearby']) {
      await tester.tap(find.byKey(Key(tile)));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(users.length, greaterThanOrEqualTo(5));
    expect(users.every((u) => identical(u, users.first)), isTrue);
  });

  testWidgets('Chat refetches on re-select (epoch), other tabs keep state', (
    tester,
  ) async {
    final chatBuilds = <int>[];
    await pumpShell(tester, chatBuilds: chatBuilds, chat: true);
    await tapNav(tester, 'Chat');
    expect(chatBuilds.length, 2); // initial IndexedStack build + epoch bump
    final afterFirst = chatBuilds.length;
    await tapNav(tester, 'Home');
    await tapNav(tester, 'Chat');
    expect(chatBuilds.length, greaterThan(afterFirst));
  });

  group('reachability: everything reachable before is still reachable', () {
    testWidgets('Profile, Directory (and Nearby), Chat via bottom nav', (
      tester,
    ) async {
      await pumpShell(tester, chat: true);
      await tapNav(tester, 'Profile');
      expect(find.text('PAGE Profile'), findsOneWidget);
      await tapNav(tester, 'Directory');
      expect(find.text('PAGE Directory'), findsOneWidget);
      await tapNav(tester, 'Chat');
      expect(find.text('PAGE Chat'), findsOneWidget);
    });

    testWidgets('Jobs, Marketplace, Nearby, News via Home', (tester) async {
      await pumpShell(tester);
      final routes = {
        'tile-jobs': 'Jobs',
        'tile-nearby': 'Nearby',
        'see-all-announcements': 'Announcements',
      };
      for (final e in routes.entries) {
        await tester.ensureVisible(find.byKey(Key(e.key)));
        await tester.tap(find.byKey(Key(e.key)));
        await tester.pumpAndSettle();
        expect(find.text('PAGE ${e.value}'), findsOneWidget, reason: e.key);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Directory tile switches to the Directory tab', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byKey(const Key('tile-directory')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE Directory'), findsOneWidget);
    });

    // The default (real) wiring: each destination builds the real screen,
    // with a back arrow when pushed from Home and none as a tab root.
    test('default pages map to the real screens', () {
      const pages = HomePages();
      final user = ValueNotifier<Map<String, dynamic>>({'id': 'me'});
      expect(pages.profile(profile, user), isA<ProfileDetailScreen>());
      expect(pages.chat(user), isA<MessagesListScreen>());
      expect(pages.market(user, ValueNotifier(0)), isA<MarketScreen>());
      final dir = pages.directory(user) as AlumniScreen;
      expect(dir.showBack, isFalse);
      expect(dir.initialTab, 0);
      final nearby = pages.nearby(user) as AlumniScreen;
      expect(nearby.showBack, isTrue);
      expect(nearby.initialTab, 1);
      expect((pages.jobs(user) as JobBoardScreen).showBack, isTrue);
      expect((pages.marketplace(user) as MarketplaceScreen).showBack, isTrue);
      expect((pages.announcements() as AnnouncementsScreen).showBack, isTrue);
    });
  });

  group('Market tab', () {
    testWidgets('opens on Products; the Home tiles switch tab and segment', (
      tester,
    ) async {
      await pumpShell(tester);
      await tapNav(tester, 'Market');
      expect(find.text('PAGE Market Products'), findsOneWidget);
      await tapNav(tester, 'Home');
      await tester.tap(find.byKey(const Key('tile-businesses')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE Market Businesses'), findsOneWidget);
      await tapNav(tester, 'Home');
      await tester.tap(find.byKey(const Key('tile-marketplace')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE Market Products'), findsOneWidget);
    });

    testWidgets('back from Market goes to Home first', (tester) async {
      await pumpShell(tester);
      await tapNav(tester, 'Market');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('Hello, Ahmad'), findsOneWidget);
    });
  });
}
