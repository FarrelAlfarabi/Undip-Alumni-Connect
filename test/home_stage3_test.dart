import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/home_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/models/marketplace_listing.dart';
import 'package:undip_alumni_connect/screens/marketplace_detail_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_form_screen.dart';
import 'package:undip_alumni_connect/theme.dart';
import 'package:undip_alumni_connect/widgets/image_size_hint.dart';

import 'home_screen_test.dart' show pumpHome;
import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

FakeApi marketWith(int n) => FakeApi()
  ..approved = [
    for (var i = 1; i <= n; i++)
      listingMap(
        id: 'l$i',
        title: 'Listing $i',
        seller: sellerMap,
        createdAt: '2026-09-${i.toString().padLeft(2, '0')}T08:00:00+00:00',
      ),
  ];

void main() {
  group('limits', () {
    test('Home shows 10 products and 3 jobs', () {
      expect(kHomeListingLimit, 10);
      expect(kHomeLatestLimit, 3);
      expect(kHomeListingFetchLimit, greaterThan(kHomeListingLimit));
    });
  });

  group('section order', () {
    testWidgets('Marketplace comes before Jobs, no "Terbaru" heading', (
      tester,
    ) async {
      await pumpHome(tester, market: marketWith(2));
      expect(find.text('Terbaru'), findsNothing);
      final market = tester.getTopLeft(find.text('Baru di Marketplace')).dy;
      final jobs = tester.getTopLeft(find.text('Lowongan baru')).dy;
      expect(market, lessThan(jobs));
    });
  });

  group('product row', () {
    testWidgets('12 listings: newest first, no arrow card', (tester) async {
      await pumpHome(tester, market: marketWith(12));
      final list = find.byKey(const Key('latest-listings-row'));
      expect(find.byKey(const Key('latest-listings-more')), findsNothing);
      await tester.ensureVisible(list);
      await tester.pump();
      expect(find.text('Listing 12'), findsOneWidget);
      await tester.drag(list, const Offset(-5000, 0));
      await tester.pump();
      expect(find.text('Listing 3'), findsOneWidget);
      expect(find.text('Listing 2'), findsNothing);
    });

    for (final (total, shown) in [(12, 10), (4, 4)]) {
      testWidgets('$total listings: $shown cards', (tester) async {
        await pumpHome(tester, market: marketWith(total));
        final row = tester.widget<ListView>(
          find.byKey(const Key('latest-listings-row')),
        );
        // separated list: n cards + n-1 gaps
        expect(row.childrenDelegate.estimatedChildCount, shown * 2 - 1);
      });
    }

    testWidgets('0 listings: empty text, no row', (tester) async {
      await pumpHome(tester);
      expect(find.textContaining('Belum ada produk'), findsOneWidget);
      expect(find.byKey(const Key('latest-listings-row')), findsNothing);
    });

    testWidgets('card shows title, category, city, price and image; opens '
        'detail', (tester) async {
      await pumpHome(tester, market: marketWith(1));
      expect(find.text('Listing 1'), findsOneWidget);
      expect(find.text('Food & Drink'), findsOneWidget);
      expect(find.text('Semarang'), findsOneWidget);
      expect(find.textContaining('85.000'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-product-card')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Listing 1'));
      await tester.tap(find.text('Listing 1'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE ListingDetail l1'), findsOneWidget);
    });

    testWidgets('card photo is 3:2', (tester) async {
      await pumpHome(tester, market: marketWith(1));
      final ratio = tester.widget<AspectRatio>(
        find
            .descendant(
              of: find.byKey(const ValueKey('home-product-card')),
              matching: find.byType(AspectRatio),
            )
            .first,
      );
      expect(ratio.aspectRatio, 3 / 2);
    });
  });

  group('see all links', () {
    testWidgets('products link opens Marketplace, jobs link opens Jobs', (
      tester,
    ) async {
      await pumpHome(tester, market: marketWith(1));
      await tester.ensureVisible(
        find.byKey(const Key('latest-listings-see-all')),
      );
      await tester.tap(find.byKey(const Key('latest-listings-see-all')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE Marketplace'), findsOneWidget);
      Navigator.of(tester.element(find.text('PAGE Marketplace'))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('latest-jobs-see-all')));
      await tester.tap(find.byKey(const Key('latest-jobs-see-all')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE Jobs'), findsOneWidget);
    });
  });

  group('job rows', () {
    testWidgets('6 jobs: exactly 3 rows', (tester) async {
      final api = FakeHomeApi(jobs: [for (var i = 6; i >= 1; i--) jobMap(i)]);
      await pumpHome(tester, api: api);
      expect(find.byKey(const ValueKey('home-job-row')), findsNWidgets(3));
    });

    testWidgets('initials square shows BM for Bank Mandiri', (tester) async {
      final api = FakeHomeApi(
        jobs: [
          {...jobMap(1), 'company': 'Bank Mandiri'},
        ],
      );
      await pumpHome(tester, api: api);
      expect(find.text('BM'), findsOneWidget);
    });

    testWidgets('row is a tappable card with a button label', (tester) async {
      final api = FakeHomeApi(jobs: [jobMap(1)]);
      await pumpHome(tester, api: api);
      final row = tester.getSize(find.byKey(const ValueKey('home-job-row')));
      expect(row.height, greaterThanOrEqualTo(64));
    });
  });

  group('business card', () {
    testWidgets('register state is yellow with a 48 dp black button', (
      tester,
    ) async {
      await pumpHome(tester);
      final card = tester.widget<Card>(
        find.byKey(const Key('business-register-card')),
      );
      expect(card.color, AppTheme.yellow);
      final size = tester.getSize(
        find.byKey(const Key('business-register-button')),
      );
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.text('Daftarkan'), findsOneWidget);
    });
  });

  group('states keep their text', () {
    testWidgets('empty jobs and error listings', (tester) async {
      final market = FakeApi()..throwOnCall = Exception('db down');
      await pumpHome(tester, market: market);
      expect(find.textContaining('Belum ada lowongan'), findsOneWidget);
      expect(find.text("Couldn't load this right now."), findsOneWidget);
    });
  });

  group('no overflow at text scale 1.3 on 360 x 640', () {
    testWidgets('product row and job rows', (tester) async {
      final market = FakeApi()
        ..approved = [
          for (var i = 1; i <= 3; i++)
            listingMap(
              id: 'l$i',
              title: 'Judul produk yang sangat panjang sekali nomor $i',
              category: 'Makanan dan Minuman Olahan',
              city: 'Kota Tangerang Selatan',
              priceIdr: 12500000,
              seller: sellerMap,
            ),
        ];
      await pumpHome(
        tester,
        size: const Size(360, 640),
        textScale: 1.3,
        market: market,
        api: FakeHomeApi(
          jobs: [
            for (var i = 1; i <= 3; i++)
              {
                ...jobMap(i),
                'title': 'Manajer Hubungan Investor Senior nomor $i',
                'company': 'PT Bank Negara Indonesia Persero Tbk',
              },
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('home-list')),
        const Offset(0, -900),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('latest-listings-row')),
        const Offset(-400, 0),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('listing photo ratio', () {
    Future<void> pumpScreen(WidgetTester tester, Widget w) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: w));
      await tester.pumpAndSettle();
    }

    testWidgets('form preview is 3:2', (tester) async {
      await pumpScreen(
        tester,
        MarketplaceFormScreen(
          sellerId: 's1',
          repository: MarketplaceRepository(FakeApi()),
        ),
      );
      final ratios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((a) => a.aspectRatio);
      expect(ratios, contains(3 / 2));
    });

    testWidgets('detail photo is 3:2', (tester) async {
      final api = FakeApi()..profile = {'id': 's1', 'name': 'Bunga'};
      await pumpScreen(
        tester,
        MarketplaceDetailScreen(
          listing: MarketplaceListing.fromMap(listingMap(seller: sellerMap)),
          repository: MarketplaceRepository(api),
          currentUser: ValueNotifier({'id': 's1'}),
        ),
      );
      final ratios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((a) => a.aspectRatio);
      expect(ratios, contains(3 / 2));
    });
  });

  group('ImageSizeHint', () {
    testWidgets('says 3:2, 1200 x 800 and 2 MB in Indonesian', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ImageSizeHint())),
      );
      expect(
        find.text('Foto terbaik: landscape 3:2 (1200 x 800 px).'),
        findsOneWidget,
      );
      expect(find.text('JPG, PNG atau WebP, maksimal 2 MB.'), findsOneWidget);
    });

    testWidgets('listing form uses it and Save stays reachable at 1.3 scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: MarketplaceFormScreen(
              sellerId: 's1',
              repository: MarketplaceRepository(FakeApi()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageSizeHint), findsOneWidget);
      expect(find.textContaining('3:2'), findsWidgets);
      expect(find.textContaining('2 MB'), findsWidgets);
      expect(
        find.text('One photo. JPG, PNG or WebP, up to 2 MB.'),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('Post product'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Post product'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
