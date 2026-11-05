import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/admin_announcements_screen.dart';
import 'package:undip_alumni_connect/screens/admin_reports_screen.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_admin_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';
import 'support/fake_marketplace_api.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('pending counts parse', () async {
    final api = FakeAdminApi()
      ..results['admin_pending_counts'] = [
        {'businesses': 2, 'listings': 1, 'reports': 3, 'feedback': 0},
      ];
    final c = await AdminRepository(api).pendingCounts('me');
    expect(api.params['admin_pending_counts'], {'p_admin': 'me'});
    expect((c.businesses, c.listings, c.reports, c.feedback), (2, 1, 3, 0));
    expect(c.total, 6);
  });

  test('approve without a band sends null', () async {
    final api = FakeAdminApi()
      ..results['admin_business_decide'] = businessMap();
    await AdminRepository(api).approve('me', 'b1');
    expect(api.params['admin_business_decide']!['p_band'], isNull);
  });

  testWidgets('red tags show only for sections with work waiting', (
    tester,
  ) async {
    phone(tester);
    final api = FakeAdminApi()
      ..results['admin_pending_counts'] = [
        {'businesses': 2, 'listings': 0, 'reports': 3, 'feedback': 1},
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          adminId: 'me',
          adminRepository: AdminRepository(api),
          marketplaceRepository: MarketplaceRepository(FakeApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder tag(String k) => find.byKey(Key('badge-$k'));
    expect(tag('admin-businesses'), findsOneWidget);
    expect(
      find.descendant(of: tag('admin-businesses'), matching: find.text('2')),
      findsOneWidget,
    );
    expect(tag('admin-reports'), findsOneWidget);
    expect(tag('admin-feedback'), findsOneWidget);
    expect(tag('admin-marketplace'), findsNothing);
  });

  group('undo next to the notification', () {
    Future<FakeAdminApi> pumpBusinesses(
      WidgetTester tester,
      Map<String, dynamic> row,
    ) async {
      phone(tester);
      final api = FakeAdminApi()
        ..results['admin_businesses_list'] = [row]
        ..results['admin_business_decide'] = businessMap(status: 'approved')
        ..results['admin_business_set_state'] = businessMap();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminBusinessesScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('approve can be undone back to pending', (tester) async {
      final api = await pumpBusinesses(tester, businessMap());
      await tester.tap(find.byKey(const Key('approve-b1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('undo-action')), findsOneWidget);
      await tester.tap(find.byKey(const Key('undo-action')));
      await tester.pumpAndSettle();
      expect(api.params['admin_business_set_state'], {
        'p_admin': 'me',
        'p_business': 'b1',
        'p_status': 'pending',
        'p_band': null,
        'p_reason': null,
      });
    });

    testWidgets('the undo button goes away with the notification', (
      tester,
    ) async {
      await pumpBusinesses(tester, businessMap());
      await tester.tap(find.byKey(const Key('approve-b1')));
      await tester.pump();
      expect(find.byKey(const Key('undo-action')), findsOneWidget);
      // The countdown starts once the notification has slid in.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('undo-action')), findsNothing);
    });

    testWidgets('deleting an announcement can be undone', (tester) async {
      phone(tester);
      final api = FakeAdminApi()
        ..results['admin_announcement_list'] = [
          {
            'id': 'a1',
            'title': 'Reuni',
            'body': 'Isi',
            'posted_by': 'p1',
            'posted_by_name': 'Gilang',
            'created_at': '2026-11-01T08:00:00+00:00',
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAnnouncementsScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-announcement-a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('undo-action')));
      await tester.pumpAndSettle();
      final p = api.params['admin_announcement_restore']!;
      expect(p['p_id'], 'a1');
      expect(p['p_title'], 'Reuni');
      expect(p['p_body'], 'Isi');
    });

    testWidgets('dismissing a report can be undone (reopen)', (tester) async {
      phone(tester);
      final api = FakeAdminApi()
        ..results['admin_reports_list'] = [
          {
            'target_type': 'job',
            'target_id': 't1',
            'title': 'Staff Keuangan',
            'owner_id': 'o',
            'owner_name': 'Ahmad',
            'report_count': 1,
            'reasons': ['spam_or_scam'],
            'notes': <String>[],
            'last_reported': '2026-10-02T00:00:00Z',
            'is_hidden': false,
            'hidden_reason': null,
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportsScreen(
            adminId: 'me',
            repository: AdminRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dismiss-t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('undo-action')));
      await tester.pumpAndSettle();
      expect(api.params['admin_reports_decide']!['p_action'], 'reopen');
      expect(api.params['admin_reports_decide']!['p_target'], 't1');
    });

    testWidgets('a marketplace review can be undone (back to pending)', (
      tester,
    ) async {
      phone(tester);
      final api = FakeApi()
        ..rpcResults['marketplace_admin_pending'] = [
          listingMap(
            id: 'p1',
            title: 'Sambal Roa',
            status: 'pending',
            approvedAt: null,
          ),
        ]
        ..rpcResults['marketplace_review_listing'] = listingMap(id: 'p1');
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceAdminScreen(
            adminId: 'me',
            repository: MarketplaceRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Approve').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('undo-action')));
      await tester.pumpAndSettle();
      expect(
        api.params['marketplace_review_listing']!['p_decision'],
        'pending',
      );
    });
  });
}
