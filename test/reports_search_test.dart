import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/screens/admin_reports_screen.dart';

import 'support/fake_admin_api.dart';

Map<String, dynamic> row({
  required String type,
  required String id,
  required String title,
  String owner = 'Ahmad',
  List<String> reasons = const ['spam_or_scam'],
  List<String> notes = const [],
}) => {
  'target_type': type,
  'target_id': id,
  'title': title,
  'owner_id': 'o',
  'owner_name': owner,
  'report_count': 1,
  'reasons': reasons,
  'notes': notes,
  'last_reported': '2026-10-02T00:00:00Z',
  'is_hidden': false,
  'hidden_reason': null,
};

void main() {
  Future<FakeAdminApi> pump(
    WidgetTester tester,
    List<Map<String, dynamic>> rows,
  ) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeAdminApi()..results['admin_reports_list'] = rows;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminReportsScreen(
          adminId: 'me',
          repository: AdminRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  final rows = [
    row(
      type: 'job',
      id: 'j1',
      title: 'Staff Keuangan',
      notes: ['lowongan palsu'],
    ),
    row(
      type: 'product',
      id: 'p1',
      title: 'Kopi Gayo',
      owner: 'Siti',
      reasons: ['inappropriate'],
    ),
    row(
      type: 'profile',
      id: 'u1',
      title: 'Budi Santoso',
      owner: 'Budi',
      reasons: ['fake_or_impersonation', 'other'],
    ),
  ];

  testWidgets('search by title, owner or note, no new load', (tester) async {
    final api = await pump(tester, rows);
    final search = find.byKey(const Key('admin-report-search'));
    expect(search, findsOneWidget);

    await tester.enterText(search, 'kopi');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-product-p1')), findsOneWidget);
    expect(find.byKey(const Key('report-job-j1')), findsNothing);

    await tester.enterText(search, 'palsu');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-job-j1')), findsOneWidget);
    expect(find.byKey(const Key('report-product-p1')), findsNothing);

    await tester.enterText(search, 'budi');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-profile-u1')), findsOneWidget);

    await tester.enterText(search, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches.'), findsOneWidget);
    expect(
      api.calls.where((c) => c == 'admin_reports_list'),
      hasLength(1),
    );
  });

  testWidgets('filter by type', (tester) async {
    await pump(tester, rows);
    await tester.tap(find.byKey(const Key('admin-report-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-profile-u1')), findsOneWidget);
    expect(find.byKey(const Key('report-job-j1')), findsNothing);
    expect(find.byKey(const Key('report-product-p1')), findsNothing);
  });

  testWidgets('filter by reason', (tester) async {
    await pump(tester, rows);
    await tester.tap(find.byKey(const Key('admin-report-reason')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inappropriate').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-product-p1')), findsOneWidget);
    expect(find.byKey(const Key('report-job-j1')), findsNothing);
    expect(find.byKey(const Key('report-profile-u1')), findsNothing);
  });

  testWidgets('search and filters also work on the Hidden tab', (tester) async {
    final api = await pump(tester, rows);
    api.results['admin_reports_list'] = [
      {...row(type: 'job', id: 'h1', title: 'Admin kerja'), 'is_hidden': true},
      {...row(type: 'job', id: 'h2', title: 'Sales'), 'is_hidden': true},
    ];
    await tester.tap(find.text('Hidden'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-report-search')),
      'sales',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-job-h2')), findsOneWidget);
    expect(find.byKey(const Key('report-job-h1')), findsNothing);
  });
}
