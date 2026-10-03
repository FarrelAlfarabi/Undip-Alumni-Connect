import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/models/marketplace_listing.dart';
import 'package:undip_alumni_connect/screens/marketplace_admin_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_detail_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_form_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_screen.dart';
import 'package:undip_alumni_connect/screens/my_listings_screen.dart';

import 'support/fake_marketplace_api.dart';

const notice = 'Demo only, no real payments';

final longTitle =
    'Laptop Bekas Core i5 Generasi Kedelapan dengan RAM 8 GB dan SSD 256 GB '
    'kondisi sangat mulus lengkap dengan charger asli dan tas';

FakeApi richApi() => FakeApi()
  ..approved = [
    listingMap(
      id: 'a',
      title: longTitle,
      priceIdr: 1500000000,
      seller: sellerMap,
      shopUrl:
          'https://example.com/toko/dengan/alamat/yang/sangat/panjang/sekali',
    ),
    listingMap(id: 'b', title: 'Kopi', seller: sellerMap),
  ]
  ..profileNames = [
    {
      'id': 's1',
      'name': 'Bunga Citra Ayu dengan Nama yang Sangat Panjang Sekali',
    },
  ]
  ..rpcResults['marketplace_my_listings'] = [
    listingMap(
      id: 'm1',
      title: longTitle,
      status: 'rejected',
      rejectedReason: 'Alasan penolakan yang cukup panjang untuk menguji pembungkusan baris teks',
      approvedAt: null,
    ),
    listingMap(id: 'm2', title: 'Kopi', status: 'approved'),
    listingMap(id: 'm3', title: 'Sold', status: 'sold'),
  ]
  ..rpcResults['marketplace_admin_pending'] = [
    listingMap(id: 'p1', title: longTitle, status: 'pending', approvedAt: null),
  ]
  ..rpcResults['marketplace_report_counts'] = [
    {'listing_id': 'a', 'report_count': 12},
  ];

/// Narrowest phone we care about, with the OS text size cranked up.
Future<void> pumpNarrow(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final me = ValueNotifier<Map<String, dynamic>>({
    'id': 's1',
    'name': 'Me',
    'subscription_status': 'subscribed',
  });

  group('demo notice on every marketplace screen', () {
    testWidgets('browse', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceScreen(
          currentUser: me,
          repository: MarketplaceRepository(richApi()),
        ),
      );
      expect(find.text(notice), findsOneWidget);
    });
    testWidgets('detail', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceDetailScreen(
          listing: MarketplaceListing.fromMap(richApi().approved.first),
          repository: MarketplaceRepository(richApi()),
          currentUser: me,
        ),
      );
      expect(find.text(notice), findsOneWidget);
    });
    testWidgets('create form', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceFormScreen(
          sellerId: 's1',
          repository: MarketplaceRepository(richApi()),
        ),
      );
      expect(find.text(notice), findsOneWidget);
    });
    testWidgets('edit form', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceFormScreen(
          sellerId: 's1',
          repository: MarketplaceRepository(richApi()),
          existing: MarketplaceListing.fromMap(listingMap(status: 'approved')),
        ),
      );
      expect(find.text(notice), findsOneWidget);
    });
    testWidgets('my listings', (tester) async {
      await pumpNarrow(
        tester,
        MyListingsScreen(
          sellerId: 's1',
          repository: MarketplaceRepository(richApi()),
        ),
      );
      expect(find.text(notice), findsOneWidget);
    });
    testWidgets('admin', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceAdminScreen(
          adminId: 'a',
          repository: MarketplaceRepository(richApi()),
        ),
      );
      expect(find.text(notice), findsOneWidget);
    });
  });

  group('no overflow at 320 px wide with 160% text', () {
    testWidgets('browse (list, filters, chips)', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceScreen(
          currentUser: me,
          repository: MarketplaceRepository(richApi()),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
    testWidgets('detail', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceDetailScreen(
          listing: MarketplaceListing.fromMap(richApi().approved.first),
          repository: MarketplaceRepository(richApi()),
          currentUser: me,
        ),
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('form', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceFormScreen(
          sellerId: 's1',
          repository: MarketplaceRepository(richApi()),
          existing: MarketplaceListing.fromMap(
            listingMap(status: 'approved', title: longTitle),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('my listings', (tester) async {
      await pumpNarrow(
        tester,
        MyListingsScreen(
          sellerId: 's1',
          repository: MarketplaceRepository(richApi()),
        ),
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('admin queue', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceAdminScreen(
          adminId: 'a',
          repository: MarketplaceRepository(richApi()),
        ),
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('admin reports', (tester) async {
      await pumpNarrow(
        tester,
        MarketplaceAdminScreen(
          adminId: 'a',
          repository: MarketplaceRepository(richApi()),
        ),
      );
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  test('no commission or fee wording in marketplace code or seed data', () {
    final banned = RegExp(
      r'commission|komisi|\bfees?\b|biaya|service charge|platform fee|admin fee|potongan|take rate',
      caseSensitive: false,
    );
    final files = <File>[
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.contains('marketplace') ||
                f.path.contains('my_listings'),
          ),
      File('supabase/seed_marketplace.sql'),
      ...Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('marketplace')),
    ];
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(
        banned.hasMatch(f.readAsStringSync()),
        isFalse,
        reason: '${f.path} mentions a fee/commission',
      );
    }
  });
}
