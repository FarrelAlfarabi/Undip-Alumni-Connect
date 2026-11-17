import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/admin_jobs_screen.dart';
import 'package:undip_alumni_connect/screens/marketplace_admin_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_marketplace_api.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> confirmDelete(WidgetTester tester, {String word = 'HAPUS'}) async {
  await tester.enterText(find.byKey(const Key('admin-reason')), 'Spam');
  await tester.enterText(find.byKey(const Key('admin-confirm-word')), word);
  await tester.tap(find.byKey(const Key('admin-reason-ok')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('admin deletes a job for good after reason and HAPUS', (
    tester,
  ) async {
    phone(tester);
    final api = FakeAdminApi()
      ..results['admin_jobs_list'] = [
        {
          'id': 'j1',
          'title': 'Staf Keuangan',
          'company': 'PT Maju',
          'poster_name': 'Siti',
          'created_at': '2026-11-01T00:00:00Z',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: AdminJobsScreen(adminId: 'me', repository: AdminRepository(api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-more-j1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-delete-j1')));
    await tester.pumpAndSettle();
    await confirmDelete(tester, word: 'salah');
    expect(api.calls, isNot(contains('admin_job_delete')));
    await confirmDelete(tester);
    expect(api.params['admin_job_delete'], {
      'p_admin': 'me',
      'p_job': 'j1',
      'p_reason': 'Spam',
    });
    expect(find.text('Lowongan dihapus.'), findsOneWidget);
  });

  testWidgets('admin deletes a reported listing for good', (tester) async {
    phone(tester);
    final api = FakeApi()
      ..rpcResults['marketplace_admin_pending'] = <dynamic>[]
      ..rpcResults['marketplace_report_details'] = [
        {
          'listing_id': 'l1',
          'title': 'Kopi Arabika',
          'seller_name': 'Bunga',
          'report_count': 1,
          'reporters': ['Ahmad'],
          'reasons': ['spam'],
          'notes': [''],
          'hidden_at': null,
          'hidden_reason': null,
        },
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
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-more-l1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-delete-l1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-reason-cancel')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('admin_listing_delete')));
    await tester.tap(find.byKey(const Key('report-more-l1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-delete-l1')));
    await tester.pumpAndSettle();
    await confirmDelete(tester);
    expect(api.params['admin_listing_delete'], {
      'p_admin': 'admin',
      'p_listing': 'l1',
      'p_reason': 'Spam',
    });
  });
}
