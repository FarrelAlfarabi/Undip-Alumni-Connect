import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:undip_alumni_connect/data/marketplace_messages.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/models/marketplace_listing.dart';
import 'package:undip_alumni_connect/screens/marketplace_admin_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_detail_screen.dart';

import 'support/fake_marketplace_api.dart';

ValueNotifier<Map<String, dynamic>> user() =>
    ValueNotifier({'id': 'me', 'name': 'Me', 'subscription_status': 'free'});

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

List<Map<String, dynamic>> pendingRows() => [
  listingMap(
    id: 'p1',
    title: 'Sambal Roa',
    status: 'pending',
    approvedAt: null,
  ),
  listingMap(
    id: 'p2',
    title: 'Desain Undangan',
    status: 'pending',
    approvedAt: null,
  ),
];

void main() {
  group('repository admin methods', () {
    late FakeApi api;
    late MarketplaceRepository repo;
    setUp(() {
      api = FakeApi();
      repo = MarketplaceRepository(api);
    });

    test('fetchPending attaches seller names', () async {
      api.rpcResults['marketplace_admin_pending'] = pendingRows();
      api.profileNames = [
        {'id': 's1', 'name': 'Bunga Citra Ayu'},
      ];
      final list = await repo.fetchPending('a');
      expect(list.map((l) => l.id), ['p1', 'p2']);
      expect(list.first.seller?.name, 'Bunga Citra Ayu');
    });

    test('review sends the decision and trims the reason', () async {
      api.rpcResult = listingMap(
        status: 'rejected',
        rejectedReason: 'x',
        approvedAt: null,
      );
      await repo.review(
        adminId: 'a',
        listingId: 'l',
        approve: false,
        reason: '  Foto buram ',
      );
      expect(api.params['marketplace_review_listing'], {
        'p_admin': 'a',
        'p_listing': 'l',
        'p_decision': 'rejected',
        'p_reason': 'Foto buram',
      });
      api.rpcResult = listingMap();
      await repo.review(
        adminId: 'a',
        listingId: 'l',
        approve: true,
        reason: 'ignored',
      );
      expect(
        api.params['marketplace_review_listing']!['p_decision'],
        'approved',
      );
      expect(api.params['marketplace_review_listing']!['p_reason'], isNull);
    });

    test('fetchReportCounts parses rows; not_admin becomes notAdmin', () async {
      api.rpcResult = [
        {'listing_id': 'l1', 'report_count': 3},
      ];
      final counts = await repo.fetchReportCounts('a');
      expect(counts.single.count, 3);

      api.throwOnCall = PostgrestException(message: 'not_admin', code: 'P0001');
      await expectLater(
        repo.fetchReportCounts('x'),
        throwsA(
          isA<MarketplaceException>().having(
            (e) => e.code,
            'code',
            MarketplaceErrorCode.notAdmin,
          ),
        ),
      );
    });
  });

  group('MarketplaceAdminScreen', () {
    Future<FakeApi> pumpAdmin(
      WidgetTester tester, {
      List<Map<String, dynamic>>? rows,
    }) async {
      phone(tester);
      final api = FakeApi()
        ..rpcResults['marketplace_admin_pending'] = rows ?? pendingRows()
        ..profileNames = [
          {'id': 's1', 'name': 'Bunga Citra Ayu'},
        ]
        ..approved = [
          listingMap(id: 'l1', title: 'Kopi Arabika', seller: sellerMap),
        ]
        ..rpcResults['marketplace_report_counts'] = [
          {'listing_id': 'l1', 'report_count': 2},
          {'listing_id': 'gone', 'report_count': 1},
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceAdminScreen(
            adminId: 'admin',
            repository: MarketplaceRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('lists pending listings with seller and the demo notice', (
      tester,
    ) async {
      await pumpAdmin(tester);
      expect(find.text('Sambal Roa'), findsOneWidget);
      expect(find.text('Desain Undangan'), findsOneWidget);
      expect(find.text('By Bunga Citra Ayu'), findsNWidgets(2));
      expect(
        find.text(
          'Lingkaran does not handle payments or delivery. Deal directly with the seller and check before you pay.',
        ),
        findsOneWidget,
      );
      // No passphrase prompt any more: the queue is shown straight away.
      expect(find.text('Admin passphrase'), findsNothing);
    });

    testWidgets('approve calls the review function and reloads', (
      tester,
    ) async {
      final api = await pumpAdmin(tester);
      api.rpcResults['marketplace_review_listing'] = listingMap(id: 'p1');
      api.rpcResults['marketplace_admin_pending'] = [pendingRows()[1]];
      await tester.tap(find.widgetWithText(FilledButton, 'Approve').first);
      await tester.pumpAndSettle();
      final p = api.params['marketplace_review_listing']!;
      expect(p['p_listing'], 'p1');
      expect(p['p_decision'], 'approved');
      expect(find.text('Approved "Sambal Roa".'), findsOneWidget);
      expect(find.text('Sambal Roa'), findsNothing);
      expect(find.text('Desain Undangan'), findsOneWidget);
    });

    testWidgets('reject needs a reason, then sends it', (tester) async {
      final api = await pumpAdmin(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(find.text('A reason is required'), findsOneWidget);
      expect(api.calls, isNot(contains('marketplace_review_listing')));

      await tester.enterText(find.byType(TextField), 'Foto kurang jelas');
      api.rpcResults['marketplace_review_listing'] = listingMap(
        id: 'p1',
        status: 'rejected',
        rejectedReason: 'Foto kurang jelas',
        approvedAt: null,
      );
      api.rpcResults['marketplace_admin_pending'] = [pendingRows()[1]];
      await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
      await tester.pumpAndSettle();
      final p = api.params['marketplace_review_listing']!;
      expect(p['p_decision'], 'rejected');
      expect(p['p_reason'], 'Foto kurang jelas');
      expect(find.text('Sambal Roa'), findsNothing);
    });

    testWidgets('cancelling the reject dialog changes nothing', (tester) async {
      final api = await pumpAdmin(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('marketplace_review_listing')));
      expect(find.text('Sambal Roa'), findsOneWidget);
    });

    testWidgets('a server error is shown as a message', (tester) async {
      final api = await pumpAdmin(tester);
      api.throwOnCall = MarketplaceException(
        MarketplaceErrorCode.invalidState,
        'invalid_state',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Approve').first);
      await tester.pumpAndSettle();
      expect(
        find.text('This listing cannot be changed in its current state.'),
        findsOneWidget,
      );
    });

    testWidgets('empty queue', (tester) async {
      await pumpAdmin(tester, rows: []);
      expect(find.text('Nothing waiting for review.'), findsOneWidget);
    });

    testWidgets('reports tab shows counts per listing', (tester) async {
      await pumpAdmin(tester);
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('Kopi Arabika'), findsOneWidget);
      expect(find.text('2 reports'), findsOneWidget);
      expect(find.text('Listing no longer available'), findsOneWidget);
      expect(find.text('1 report'), findsOneWidget);
    });
  });

  group('report sheet', () {
    Future<FakeApi> pumpDetail(WidgetTester tester) async {
      phone(tester);
      final api = FakeApi();
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceDetailScreen(
            listing: MarketplaceListing.fromMap(
              listingMap(id: 'l9', seller: sellerMap),
            ),
            repository: MarketplaceRepository(api),
            currentUser: user(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Report listing'));
      await tester.tap(find.text('Report listing'));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('lists the four reasons', (tester) async {
      await pumpDetail(tester);
      for (final r in ['Spam', 'Prohibited item', 'Misleading', 'Other']) {
        expect(find.text(r), findsOneWidget);
      }
    });

    testWidgets('needs a reason before sending', (tester) async {
      final api = await pumpDetail(tester);
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a reason'), findsOneWidget);
      expect(api.reports, isEmpty);
    });

    testWidgets('sends reason and note, then confirms', (tester) async {
      final api = await pumpDetail(tester);
      await tester.tap(find.text('Misleading'));
      await tester.enterText(find.byType(TextField), 'Harga tidak sesuai');
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(api.reports.single, {
        'listing_id': 'l9',
        'reporter': 'me',
        'reason': 'misleading',
        'note': 'Harga tidak sesuai',
      });
      expect(find.text(kReportSentMessage), findsOneWidget);
      expect(find.text('Send report'), findsNothing);
    });

    testWidgets(
      'a duplicate report shows a clear message and keeps the sheet',
      (tester) async {
        final api = await pumpDetail(tester);
        api.throwOnCall = MarketplaceException(
          MarketplaceErrorCode.duplicateReport,
          'dup',
        );
        await tester.tap(find.text('Spam'));
        await tester.tap(find.text('Send report'));
        await tester.pumpAndSettle();
        expect(find.text('You already reported this listing.'), findsOneWidget);
        expect(find.text('Send report'), findsOneWidget);
      },
    );
  });
}
