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
  DateTime? at,
}) => {
  'target_type': type,
  'target_id': id,
  'title': title,
  'owner_id': 'o',
  'owner_name': owner,
  'report_count': 1,
  'reasons': reasons,
  'notes': notes,
  'last_reported': (at ?? DateTime.now()).toUtc().toIso8601String(),
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
    expect(api.calls.where((c) => c == 'admin_reports_list'), hasLength(1));
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
    await tester.tap(find.byTooltip('Hidden items'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-report-search')),
      'sales',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-job-h2')), findsOneWidget);
    expect(find.byKey(const Key('report-job-h1')), findsNothing);
  });

  testWidgets('no Hidden tab; hidden items sit behind one icon', (
    tester,
  ) async {
    await pump(tester, rows);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.text('Hidden'), findsNothing);
    expect(find.byTooltip('Hidden items'), findsOneWidget);
    await tester.tap(find.byTooltip('Hidden items'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hidden items'), findsNothing);
    expect(find.text('Hidden items'), findsOneWidget);
  });

  testWidgets('every card: main action on top, full width, same place', (
    tester,
  ) async {
    await pump(tester, rows);
    final hide = tester.getRect(find.byKey(const Key('hide-p1')));
    final suspend = tester.getRect(find.byKey(const Key('suspend-u1')));
    final handled = tester.getRect(find.byKey(const Key('hide-j1')));
    expect(hide.left, suspend.left);
    expect(hide.width, suspend.width);
    expect(handled.left, hide.left);
    expect(handled.width, hide.width);
    // Dismiss is always under the main action, never beside it.
    final dismiss = tester.getRect(find.byKey(const Key('dismiss-p1')));
    expect(dismiss.top, greaterThan(hide.bottom));
    // Profile: Dismiss and Mark as handled share one row under Suspend.
    final pd = tester.getRect(find.byKey(const Key('dismiss-u1')));
    final pa = tester.getRect(find.byKey(const Key('actioned-u1')));
    expect(pd.top, greaterThan(suspend.bottom));
    expect(pa.top, pd.top);
  });

  testWidgets('filter by period', (tester) async {
    final now = DateTime.now();
    await pump(tester, [
      row(type: 'job', id: 'new', title: 'Fresh', at: now),
      row(
        type: 'job',
        id: 'wk',
        title: 'Last week',
        at: now.subtract(const Duration(days: 5)),
      ),
      row(
        type: 'job',
        id: 'mo',
        title: 'Last month',
        at: now.subtract(const Duration(days: 20)),
      ),
      row(
        type: 'job',
        id: 'old',
        title: 'Ancient',
        at: now.subtract(const Duration(days: 90)),
      ),
    ]);
    Finder card(String id) => find.byKey(Key('report-job-$id'));
    expect(card('old'), findsOneWidget);

    Future<void> pick(String label) async {
      await tester.tap(find.byKey(const Key('admin-report-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await pick('Today');
    expect(card('new'), findsOneWidget);
    expect(card('wk'), findsNothing);

    await pick('Last 7 days');
    expect(card('new'), findsOneWidget);
    expect(card('wk'), findsOneWidget);
    expect(card('mo'), findsNothing);

    await pick('Last 30 days');
    expect(card('mo'), findsOneWidget);
    expect(card('old'), findsNothing);

    await pick('All time');
    expect(card('old'), findsOneWidget);
  });

  testWidgets('no "New" tag on a report card', (tester) async {
    await pump(tester, rows);
    expect(find.text('New'), findsNothing);
    expect(find.text('new'), findsNothing);
  });
}
