import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/announcement_detail_screen.dart';
import 'package:undip_alumni_connect/screens/home_screen.dart';
import 'package:undip_alumni_connect/widgets/banner_carousel.dart';

import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

final user = ValueNotifier<Map<String, dynamic>>({
  'id': 'me',
  'name': 'Ahmad Ramadhan',
  'subscription_status': 'free',
});

Future<void> pumpHome(
  WidgetTester tester, {
  FakeHomeApi? api,
  FakeApi? market,
  VoidCallback? onDirectory,
  Size size = const Size(390, 844),
  double textScale = 1,
  Duration autoAdvance = const Duration(seconds: 5),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: HomeScreen(
          currentUser: user,
          onOpenDirectory: onDirectory ?? () {},
          pages: fakePages(),
          api: api ?? FakeHomeApi(),
          marketplaceRepository: MarketplaceRepository(market ?? FakeApi()),
          autoAdvance: autoAdvance,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  announcementDetailTests();
  group('greeting', () {
    testWidgets('uses the first name only', (tester) async {
      await pumpHome(tester);
      expect(find.text('Hello, Ahmad'), findsOneWidget);
    });

    test('firstNameOf handles empty and missing names', () {
      expect(firstNameOf({'name': '  '}), isNull);
      expect(firstNameOf({}), isNull);
      expect(firstNameOf({'name': 'Bunga  Citra Ayu'}), 'Bunga');
    });
  });

  group('banner carousel', () {
    testWidgets('0 announcements: static welcome card, no dots', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.byKey(const Key('banner-welcome')), findsOneWidget);
      expect(find.byKey(const Key('banner-pages')), findsNothing);
      expect(find.byKey(const Key('banner-dots')), findsNothing);
      // The News screen stays reachable even with nothing to show.
      expect(find.byKey(const Key('see-all-announcements')), findsOneWidget);
    });

    testWidgets('1 announcement: shown, no dots, never auto-advances', (
      tester,
    ) async {
      await pumpHome(
        tester,
        api: FakeHomeApi(announcements: [announcementMap(1)]),
      );
      expect(find.text('Announcement 1'), findsOneWidget);
      expect(find.byKey(const Key('banner-dots')), findsNothing);
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('Announcement 1'), findsOneWidget);
    });

    testWidgets('many: dots, auto-advance, swipe and tap-to-open', (
      tester,
    ) async {
      final items = [for (var i = 1; i <= 4; i++) announcementMap(i)];
      await pumpHome(tester, api: FakeHomeApi(announcements: items));

      expect(
        find.descendant(
          of: find.byKey(const Key('banner-dots')),
          matching: find.byType(AnimatedContainer),
        ),
        findsNWidgets(4),
      );
      expect(find.text('Announcement 1'), findsOneWidget);

      // Auto-advance after the interval.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Announcement 2'), findsOneWidget);

      // Manual swipe to the next page.
      await tester.drag(
        find.byKey(const Key('banner-pages')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Announcement 3'), findsOneWidget);

      // Tapping a banner opens the full announcement.
      await tester.tap(find.text('Announcement 3'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE AnnouncementDetail an3'), findsOneWidget);
    });

    testWidgets('shows at most 5 banners', (tester) async {
      final items = [for (var i = 1; i <= 9; i++) announcementMap(i)];
      await pumpHome(tester, api: FakeHomeApi(announcements: items));
      expect(
        find.descendant(
          of: find.byKey(const Key('banner-dots')),
          matching: find.byType(AnimatedContainer),
        ),
        findsNWidgets(5),
      );
    });

    testWidgets('error state offers retry and recovers', (tester) async {
      final api = FakeHomeApi(announcementsError: Exception('boom'));
      await pumpHome(tester, api: api);
      expect(find.byKey(const Key('banner-error')), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing); // no raw error text

      api.announcementsError = null;
      api.announcements = [announcementMap(1)];
      await tester.tap(find.text('Try again').first);
      await tester.pump();
      await tester.pump();
      expect(find.text('Announcement 1'), findsOneWidget);
    });

    testWidgets('loading state shows a spinner', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentUser: user,
            onOpenDirectory: () {},
            pages: fakePages(),
            api: FakeHomeApi(announcements: [announcementMap(1)]),
            marketplaceRepository: MarketplaceRepository(FakeApi()),
          ),
        ),
      );
      expect(find.byKey(const Key('banner-loading')), findsOneWidget);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('banner-loading')), findsNothing);
    });

    testWidgets('carousel stops its timer when disposed', (tester) async {
      await pumpHome(
        tester,
        api: FakeHomeApi(
          announcements: [announcementMap(1), announcementMap(2)],
        ),
      );
      await tester.pumpWidget(const SizedBox());
      // A leaked periodic timer would fail the test framework's check.
      expect(find.byType(BannerCarousel), findsNothing);
    });
  });

  group('quick-action tiles', () {
    Future<void> tapAndExpect(
      WidgetTester tester,
      String key,
      String page,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.text('PAGE $page'), findsOneWidget);
    }

    testWidgets(
      'Jobs opens the job board',
      (t) => tapAndExpect(t, 'tile-jobs', 'Jobs'),
    );
    testWidgets(
      'Marketplace opens the marketplace',
      (t) => tapAndExpect(t, 'tile-marketplace', 'Marketplace'),
    );
    testWidgets(
      'Nearby Alumni opens Nearby',
      (t) => tapAndExpect(t, 'tile-nearby', 'Nearby'),
    );

    testWidgets('Directory switches to the Directory tab via the shell', (
      tester,
    ) async {
      var opened = 0;
      await pumpHome(tester, onDirectory: () => opened++);
      await tester.tap(find.byKey(const Key('tile-directory')));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('See all announcements opens the announcements screen', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.ensureVisible(
        find.byKey(const Key('see-all-announcements')),
      );
      await tester.tap(find.byKey(const Key('see-all-announcements')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE Announcements'), findsOneWidget);
    });
  });

  group('latest strip', () {
    testWidgets('empty: intentional empty states, no fee wording', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.textContaining('No jobs posted yet'), findsOneWidget);
      expect(find.textContaining('No listings yet'), findsOneWidget);
      expect(
        find.textContaining(RegExp('fee|commission', caseSensitive: false)),
        findsNothing,
      );
    });

    testWidgets('filled: 3 newest each, opens the existing detail screens', (
      tester,
    ) async {
      final market = FakeApi()
        ..approved = [
          for (var i = 1; i <= 5; i++)
            listingMap(
              id: 'l$i',
              title: 'Listing $i',
              seller: sellerMap,
              createdAt: '2026-09-0${i}T08:00:00+00:00',
            ),
        ];
      final api = FakeHomeApi(jobs: [for (var i = 5; i >= 1; i--) jobMap(i)]);
      await pumpHome(tester, api: api, market: market);

      // Newest three listings (5, 4, 3); not 2 or 1.
      expect(find.text('Listing 5'), findsOneWidget);
      expect(find.text('Listing 3'), findsOneWidget);
      expect(find.text('Listing 2'), findsNothing);
      expect(find.text('Job 5'), findsOneWidget);
      expect(find.text('Job 3'), findsOneWidget);
      expect(find.text('Job 2'), findsNothing);

      await tester.ensureVisible(find.text('Job 5'));
      await tester.tap(find.text('Job 5'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE JobDetail j5'), findsOneWidget);
      Navigator.of(tester.element(find.text('PAGE JobDetail j5'))).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Listing 5'));
      await tester.tap(find.text('Listing 5'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE ListingDetail l5'), findsOneWidget);
    });

    testWidgets('one strip failing does not break the other', (tester) async {
      final api = FakeHomeApi(jobs: [jobMap(1)])..jobsError = null;
      final market = FakeApi()..throwOnCall = Exception('db down');
      await pumpHome(tester, api: api, market: market);
      expect(find.text('Job 1'), findsOneWidget);
      expect(find.text("Couldn't load this right now."), findsOneWidget);
      expect(find.textContaining('db down'), findsNothing);
    });
  });

  group('layout', () {
    for (final width in [320.0, 360.0, 390.0]) {
      testWidgets('no overflow at ${width.toInt()} px wide, large text', (
        tester,
      ) async {
        final market = FakeApi()
          ..approved = [
            listingMap(
              id: 'l1',
              title: 'A very long listing title that should be cut off cleanly',
              seller: sellerMap,
            ),
          ];
        await pumpHome(
          tester,
          size: Size(width, 640),
          textScale: 1.4,
          api: FakeHomeApi(
            announcements: [announcementMap(1), announcementMap(2)],
            jobs: [jobMap(1)],
          ),
          market: market,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byKey(const Key('home-list')),
          const Offset(0, -600),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

void announcementDetailTests() {
  testWidgets('announcement detail shows full title, body and date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnnouncementDetailScreen(announcement: announcementMap(2)),
      ),
    );
    expect(find.text('Announcement 2'), findsOneWidget);
    expect(find.text('Body text 2'), findsOneWidget);
    expect(find.text('Posted 12 Sep 2026'), findsOneWidget);
  });
}
