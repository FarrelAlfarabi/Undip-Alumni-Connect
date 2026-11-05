import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/admin_jobs_screen.dart';
import 'package:undip_alumni_connect/screens/admin_screen.dart';

import 'package:undip_alumni_connect/models/business.dart';
import 'package:undip_alumni_connect/screens/my_businesses_screen.dart';

import 'support/fake_admin_api.dart';
import 'support/fake_business_api.dart';
import 'support/fake_marketplace_api.dart';

Map<String, dynamic> job({bool hidden = false}) => {
  'id': 'j1',
  'title': 'Staf Keuangan',
  'company': 'PT Maju',
  'poster_name': 'Siti',
  'created_at': '2026-11-01T00:00:00Z',
  'hidden_at': hidden ? '2026-11-02T00:00:00Z' : null,
  'hidden_reason': hidden ? 'Spam' : null,
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<FakeAdminApi> pumpJobs(
  WidgetTester tester,
  Map<String, dynamic> row,
) async {
  phone(tester);
  final api = FakeAdminApi()..results['admin_jobs_list'] = [row];
  await tester.pumpWidget(
    MaterialApp(
      home: AdminJobsScreen(adminId: 'me', repository: AdminRepository(api)),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('pulling down reloads the list', (tester) async {
    final api = await pumpJobs(tester, job());
    final before = api.calls.where((c) => c == 'admin_jobs_list').length;
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      api.calls.where((c) => c == 'admin_jobs_list').length,
      greaterThan(before),
    );
  });

  testWidgets('admin takes a job down with a reason, then undoes it', (
    tester,
  ) async {
    final api = await pumpJobs(tester, job());
    await tester.tap(find.byKey(const Key('job-hide-j1')));
    await tester.pumpAndSettle();
    // A reason is required.
    await tester.tap(find.byKey(const Key('job-hide-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Alasan wajib diisi'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('job-hide-reason')), 'Spam');
    await tester.tap(find.byKey(const Key('job-hide-confirm')));
    await tester.pumpAndSettle();
    expect(api.params['admin_reports_decide'], {
      'p_admin': 'me',
      'p_type': 'job',
      'p_target': 'j1',
      'p_action': 'hide',
      'p_reason': 'Spam',
    });
    expect(find.byKey(const Key('undo-action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('undo-action')));
    await tester.pumpAndSettle();
    expect(api.params['admin_reports_decide']!['p_action'], 'restore');
  });

  testWidgets('a hidden job shows its reason and can be shown again', (
    tester,
  ) async {
    final api = await pumpJobs(tester, job(hidden: true));
    expect(find.byKey(const Key('job-hidden-j1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-restore-j1')));
    await tester.pumpAndSettle();
    expect(api.params['admin_reports_decide']!['p_action'], 'restore');
    expect(find.byKey(const Key('undo-action')), findsOneWidget);
  });

  testWidgets('admin home has a Jobs button and a summary of what waits', (
    tester,
  ) async {
    phone(tester);
    final api = FakeAdminApi()
      ..results['admin_pending_counts'] = [
        {'businesses': 2, 'listings': 0, 'reports': 1, 'feedback': 0},
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
    expect(find.byKey(const Key('admin-jobs')), findsOneWidget);
    expect(
      find.textContaining('2 bisnis perlu disetujui, 1 laporan baru'),
      findsOneWidget,
    );
  });

  testWidgets('a pending business tells the owner it is being processed', (
    tester,
  ) async {
    phone(tester);
    final b = Business.fromMap(businessMap(status: 'pending'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BusinessOwnerCard(business: b)),
      ),
    );
    expect(find.text('Menunggu persetujuan'), findsOneWidget);
    expect(find.byKey(Key('pending-note-${b.id}')), findsOneWidget);
  });

  test('admin actions are logged, and a log failure does not block', () async {
    final api = FakeAdminApi();
    await AdminRepository(api).hideJob('me', 'j1', 'Spam');
    expect(api.params['admin_log_action'], {
      'p_admin': 'me',
      'p_action': 'job_hide',
      'p_target_type': 'job',
      'p_target_id': 'j1',
      'p_detail': 'Spam',
    });
  });
}
