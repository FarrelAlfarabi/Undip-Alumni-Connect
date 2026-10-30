import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/home_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/announcement_detail_screen.dart';
import 'package:undip_alumni_connect/screens/home_screen.dart';
import 'package:undip_alumni_connect/theme.dart';
import 'package:undip_alumni_connect/widgets/banner_carousel.dart';
import 'package:undip_alumni_connect/widgets/brand_lockup.dart';

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
  Map<String, dynamic>? profile,
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
          currentUser: profile == null ? user : ValueNotifier(profile),
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
  hubTests();
  announcementDetailTests();
  testWidgets('app bar is white with only the Ikafe UNDIP logo', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, Colors.white);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IkafeLogo),
      ),
      findsOneWidget,
    );
    final image = tester.widget<Image>(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Image)),
    );
    expect(image.height, 28);
    expect(find.bySemanticsLabel('IKAFE UNDIP'), findsOneWidget);
    // No chip around the logo and no app name in the header.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Lingkaran'),
      ),
      findsNothing,
    );
    expect(find.text('by Ikafe UNDIP'), findsNothing);
    for (final k in ['home-notifications', 'home-requests']) {
      final size = tester.getSize(find.byKey(Key(k)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    handle.dispose();
  });

  group('greeting second line', () {
    testWidgets('shows major and angkatan', (tester) async {
      await pumpHome(
        tester,
        profile: {
          'id': 'me',
          'name': 'Ahmad Ramadhan',
          'major': 'Manajemen',
          'graduation_year': 2019,
        },
      );
      expect(find.text('Manajemen · Angkatan 2019'), findsOneWidget);
    });

    testWidgets('shows only the part that exists', (tester) async {
      await pumpHome(
        tester,
        profile: {'id': 'me', 'name': 'Ahmad', 'graduation_year': 2019},
      );
      expect(find.text('Angkatan 2019'), findsOneWidget);
    });

    testWidgets('falls back to the question when both are empty', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(
        find.text('Apa yang ingin kamu lakukan hari ini?'),
        findsOneWidget,
      );
    });
  });

  group('hero card', () {
    testWidgets('is black, has a Lihat detail button that opens the detail', (
      tester,
    ) async {
      await pumpHome(
        tester,
        api: FakeHomeApi(announcements: [announcementMap(1)]),
      );
      final card = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const Key('banner-hero-0')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, AppTheme.black);
      expect(find.text('IKAFE'), findsOneWidget);
      await tester.tap(find.text('Lihat detail'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE AnnouncementDetail an1'), findsOneWidget);
    });

    testWidgets('whole card still opens the detail', (tester) async {
      await pumpHome(
        tester,
        api: FakeHomeApi(announcements: [announcementMap(1)]),
      );
      await tester.tap(find.text('Announcement 1'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE AnnouncementDetail an1'), findsOneWidget);
    });

    testWidgets(
      '360x640 at text scale 1.3: no overflow, title clear of shape',
      (tester) async {
        await pumpHome(
          tester,
          size: const Size(360, 640),
          textScale: 1.3,
          api: FakeHomeApi(
            announcements: [
              {
                ...announcementMap(1),
                'title':
                    'Pengumuman penting tentang reuni akbar alumni FEB Undip',
                'body':
                    'Isi pengumuman yang cukup panjang untuk dua baris teks '
                    'pada layar kecil dengan ukuran huruf besar.',
              },
              announcementMap(2),
            ],
            pendingRequests: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        final shape = tester.getRect(
          find.byKey(const Key('hero-corner-shape')),
        );
        final title = tester.getRect(
          find.text('Pengumuman penting tentang reuni akbar alumni FEB Undip'),
        );
        expect(title.overlaps(shape), isFalse);
        expect(
          tester.getSize(find.byKey(const Key('banner-pages'))).height,
          greaterThan(172),
        );
      },
    );

    testWidgets('dots: active pill 18x6, inactive 6x6; see all on same row', (
      tester,
    ) async {
      await pumpHome(
        tester,
        api: FakeHomeApi(
          announcements: [announcementMap(1), announcementMap(2)],
        ),
      );
      final dots = find.descendant(
        of: find.byKey(const Key('banner-dots')),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(dots.at(0)), const Size(18, 6));
      expect(tester.getSize(dots.at(1)), const Size(6, 6));
      expect(
        tester.getCenter(find.byKey(const Key('see-all-announcements'))).dy,
        closeTo(tester.getCenter(find.byKey(const Key('banner-dots'))).dy, 2),
      );
    });
  });

  group('tiles 2x2', () {
    testWidgets('grid order, size and semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester);
      final d = tester.getRect(find.byKey(const Key('tile-directory')));
      final j = tester.getRect(find.byKey(const Key('tile-jobs')));
      final m = tester.getRect(find.byKey(const Key('tile-marketplace')));
      final k = tester.getRect(find.byKey(const Key('tile-kontak-ikafe')));
      expect(d.top, j.top);
      expect(m.top, k.top);
      expect(m.top, greaterThan(d.bottom - 1));
      expect(d.left, m.left);
      expect(j.left, k.left);
      for (final r in [d, j, m, k]) {
        expect(r.height, greaterThanOrEqualTo(64));
      }
      expect(find.text('Lowongan dari alumni'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Lowongan dari alumni')),
        findsWidgets,
      );
      expect(find.byKey(const Key('tile-businesses')), findsNothing);
      handle.dispose();
    });
  });

  group('pinned top bar', () {
    testWidgets('greeting and notifications stay visible after scrolling', (
      tester,
    ) async {
      await pumpHome(tester);
      final greetingTop = tester.getTopLeft(
        find.byKey(const Key('home-greeting')),
      );
      await tester.drag(
        find.byKey(const Key('home-list')),
        const Offset(0, -600),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('home-greeting')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('home-greeting'))),
        greetingTop,
      );
      expect(
        find.byKey(const Key('home-notifications')).hitTestable(),
        findsOneWidget,
      );
    });
  });

  group('greeting', () {
    testWidgets('uses the first name only', (tester) async {
      await pumpHome(tester);
      expect(find.text('Halo, Ahmad'), findsOneWidget);
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
      await tester.tap(find.text('Coba lagi').first);
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
      'Kontak Ikafe opens Kontak Ikafe',
      (t) => tapAndExpect(t, 'tile-kontak-ikafe', 'KontakIkafe'),
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
      expect(find.textContaining('Belum ada lowongan'), findsOneWidget);
      expect(find.textContaining('Belum ada produk'), findsOneWidget);
      expect(
        find.textContaining(RegExp('fee|commission', caseSensitive: false)),
        findsNothing,
      );
    });

    testWidgets('asks the server for a capped number of listings', (
      tester,
    ) async {
      final market = FakeApi()..approved = [listingMap(seller: sellerMap)];
      await pumpHome(tester, market: market);
      expect(market.lastLimit, kHomeListingFetchLimit);
      expect(kHomeListingFetchLimit, greaterThan(kHomeLatestLimit));
    });

    testWidgets(
      'filled: newest products and 3 newest jobs, opens the existing detail screens',
      (tester) async {
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

        // Newest listing first; Home now shows up to kHomeListingLimit.
        expect(find.text('Listing 5'), findsOneWidget);
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
      },
    );

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

void hubTests() {
  group('Home hub', () {
    testWidgets('no requests card when nobody is waiting', (tester) async {
      await pumpHome(tester);
      expect(find.byKey(const Key('home-requests-card')), findsNothing);
    });

    testWidgets('a waiting request shows a card that opens Requests', (
      tester,
    ) async {
      await pumpHome(tester, api: FakeHomeApi(pendingRequests: 2));
      expect(find.byKey(const Key('home-requests-card')), findsOneWidget);
      expect(find.textContaining('2 alumni ingin terhubung'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-requests-card')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE Requests'), findsOneWidget);
    });

    testWidgets('a profile with no city or role gets a completion card', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.byKey(const Key('home-profile-card')), findsOneWidget);
      expect(find.textContaining('Lengkapi profilmu'), findsOneWidget);
    });

    testWidgets('a complete profile has no completion card', (tester) async {
      await pumpHome(
        tester,
        profile: {
          'id': 'me',
          'name': 'Ahmad Ramadhan',
          'city': 'Semarang',
          'current_role': 'Analis',
        },
      );
      expect(find.byKey(const Key('home-profile-card')), findsNothing);
    });

    testWidgets('tiles say what they are for; Businesses has no tile', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.text('Cari alumni'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Lowongan dari alumni')),
        findsWidgets,
      );
      expect(find.byKey(const Key('tile-businesses')), findsNothing);
    });
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
