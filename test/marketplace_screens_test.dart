import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_format.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/models/marketplace_listing.dart';
import 'package:undip_alumni_connect/screens/marketplace_detail_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_screen.dart';
import 'package:undip_alumni_connect/screens/profile_detail_screen.dart';

import 'support/fake_marketplace_api.dart';

final currentUser = ValueNotifier<Map<String, dynamic>>({
  'id': 'me',
  'name': 'Me',
  'subscription_status': 'free',
});

List<Map<String, dynamic>> sampleRows() => [
  listingMap(
    id: 'a',
    title: 'Kopi Arabika',
    priceIdr: 85000,
    category: 'Food & Drink',
    seller: sellerMap,
    createdAt: '2026-09-10T08:00:00+00:00',
  ),
  listingMap(
    id: 'b',
    title: 'Laptop Bekas',
    priceIdr: 3750000,
    category: 'Electronics',
    city: 'Jakarta',
    seller: sellerMap,
    createdAt: '2026-09-12T08:00:00+00:00',
  ),
  listingMap(
    id: 'c',
    title: 'Batik Tulis',
    priceIdr: 450000,
    category: 'Fashion',
    seller: sellerMap,
    createdAt: '2026-09-11T08:00:00+00:00',
  ),
];

Future<FakeApi> pumpMarket(
  WidgetTester tester, {
  List<Map<String, dynamic>>? rows,
  Object? error,
}) async {
  // Phone-sized viewport.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = FakeApi()
    ..approved = rows ?? sampleRows()
    ..throwOnCall = error;
  await tester.pumpWidget(
    MaterialApp(
      home: MarketplaceScreen(
        currentUser: currentUser,
        repository: MarketplaceRepository(api),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

double topOf(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  group('formatting', () {
    test('formatRupiah', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(999), 'Rp 999');
      expect(formatRupiah(1500000), 'Rp 1.500.000');
      expect(formatRupiah(85000), 'Rp 85.000');
    });
  });

  group('MarketplaceScreen', () {
    testWidgets('shows listings, prices and the demo notice', (tester) async {
      await pumpMarket(tester);
      expect(find.text('Kopi Arabika'), findsOneWidget);
      expect(find.text('Rp 3.750.000'), findsOneWidget);
      expect(find.text('Electronics · Jakarta'), findsOneWidget);
      expect(
        find.text(
          'Lingkaran does not handle payments or delivery. Deal directly with the seller and check before you pay.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('default order is newest first', (tester) async {
      await pumpMarket(tester);
      expect(
        topOf(tester, 'Laptop Bekas'),
        lessThan(topOf(tester, 'Batik Tulis')),
      );
      expect(
        topOf(tester, 'Batik Tulis'),
        lessThan(topOf(tester, 'Kopi Arabika')),
      );
    });

    testWidgets('search filters by title', (tester) async {
      await pumpMarket(tester);
      await tester.enterText(find.byType(TextField), 'batik');
      await tester.pumpAndSettle();
      expect(find.text('Batik Tulis'), findsOneWidget);
      expect(find.text('Kopi Arabika'), findsNothing);
    });

    testWidgets('category chip filters, clear filters resets', (tester) async {
      await pumpMarket(tester);
      final chip = find.widgetWithText(ChoiceChip, 'Fashion');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Batik Tulis'), findsOneWidget);
      expect(find.text('Laptop Bekas'), findsNothing);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Laptop Bekas'), findsOneWidget);
      expect(find.text('Kopi Arabika'), findsOneWidget);
    });

    testWidgets('no match shows the filtered empty message', (tester) async {
      await pumpMarket(tester);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No listings match these filters.'), findsOneWidget);
    });

    testWidgets('sort by price low to high and high to low', (tester) async {
      await pumpMarket(tester);
      Future<void> pick(String label) async {
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await pick('Price: low to high');
      expect(
        topOf(tester, 'Kopi Arabika'),
        lessThan(topOf(tester, 'Batik Tulis')),
      );
      expect(
        topOf(tester, 'Batik Tulis'),
        lessThan(topOf(tester, 'Laptop Bekas')),
      );

      await pick('Price: high to low');
      expect(
        topOf(tester, 'Laptop Bekas'),
        lessThan(topOf(tester, 'Batik Tulis')),
      );
      expect(
        topOf(tester, 'Batik Tulis'),
        lessThan(topOf(tester, 'Kopi Arabika')),
      );
    });

    testWidgets('empty state when there are no approved listings', (
      tester,
    ) async {
      await pumpMarket(tester, rows: []);
      expect(find.textContaining('No listings yet'), findsOneWidget);
      expect(
        find.text(
          'Lingkaran does not handle payments or delivery. Deal directly with the seller and check before you pay.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('loading state shows a spinner before data arrives', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final api = FakeApi()..approved = sampleRows();
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceScreen(
            currentUser: currentUser,
            repository: MarketplaceRepository(api),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('error state offers retry that reloads', (tester) async {
      final api = await pumpMarket(tester, error: Exception('boom'));
      expect(
        find.textContaining('Could not load the marketplace'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Lingkaran does not handle payments or delivery. Deal directly with the seller and check before you pay.',
        ),
        findsOneWidget,
      );

      api.throwOnCall = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Kopi Arabika'), findsOneWidget);
    });
  });

  group('MarketplaceDetailScreen', () {
    Future<(FakeApi, List<Uri>)> pumpDetail(
      WidgetTester tester,
      Map<String, dynamic> row, {
      VoidCallback? onReport,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final api = FakeApi()..profile = {'id': 's1', 'name': 'Bunga Citra Ayu'};
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceDetailScreen(
            listing: MarketplaceListing.fromMap(row),
            repository: MarketplaceRepository(api),
            currentUser: currentUser,
            openUrl: (uri) async {
              opened.add(uri);
              return true;
            },
            onReport: onReport,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (api, opened);
    }

    testWidgets('shows price, description, seller card and notice', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        listingMap(seller: sellerMap, shopUrl: 'https://example.com/toko'),
      );
      expect(find.text('Rp 85.000'), findsOneWidget);
      expect(find.text('Sangrai medium'), findsOneWidget);
      expect(find.text('Posted 19 Sep 2026'), findsOneWidget);
      expect(find.text('Bunga Citra Ayu'), findsOneWidget);
      expect(find.textContaining('Class of 2016'), findsOneWidget);
      expect(
        find.text(
          'Lingkaran does not handle payments or delivery. Deal directly with the seller and check before you pay.',
        ),
        findsOneWidget,
      );
      expect(find.text('Report listing'), findsOneWidget);
    });

    testWidgets('Visit shop opens the shop url', (tester) async {
      final (_, opened) = await pumpDetail(
        tester,
        listingMap(seller: sellerMap, shopUrl: 'https://example.com/toko'),
      );
      await tester.ensureVisible(find.text('Visit shop'));
      await tester.tap(find.text('Visit shop'));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'https://example.com/toko');
    });

    testWidgets('Contact seller reveals contact info', (tester) async {
      await pumpDetail(
        tester,
        listingMap(seller: sellerMap, shopUrl: 'https://example.com/toko'),
      );
      expect(find.text('WA 0800-0000-0000'), findsNothing);
      await tester.ensureVisible(find.text('Contact seller'));
      await tester.tap(find.text('Contact seller'));
      await tester.pumpAndSettle();
      expect(find.text('WA 0800-0000-0000'), findsOneWidget);
    });

    testWidgets('only the actions the seller provided are shown', (
      tester,
    ) async {
      await pumpDetail(tester, listingMap(seller: sellerMap));
      expect(find.text('Visit shop'), findsNothing);
      expect(find.text('Contact seller'), findsOneWidget);
    });

    testWidgets('shop-only listing has no contact button', (tester) async {
      await pumpDetail(
        tester,
        listingMap(
          seller: sellerMap,
          shopUrl: 'https://example.com/toko',
          contactInfo: null,
        ),
      );
      expect(find.text('Visit shop'), findsOneWidget);
      expect(find.text('Contact seller'), findsNothing);
    });

    testWidgets('seller card opens the seller profile', (tester) async {
      final (api, _) = await pumpDetail(tester, listingMap(seller: sellerMap));
      await tester.tap(find.text('Bunga Citra Ayu'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('profile'));
      expect(find.byType(ProfileDetailScreen), findsOneWidget);
    });

    testWidgets('Report listing calls the report hook', (tester) async {
      var reported = false;
      await pumpDetail(
        tester,
        listingMap(seller: sellerMap),
        onReport: () => reported = true,
      );
      await tester.ensureVisible(find.text('Report listing'));
      await tester.tap(find.text('Report listing'));
      expect(reported, isTrue);
    });
  });
}
