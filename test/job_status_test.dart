import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/job_board_screen.dart';
import 'package:undip_alumni_connect/screens/job_detail_screen.dart';

void main() {
  final open = {
    'id': 'o',
    'title': 'Open Job',
    'company': 'A',
    'description': 'x',
  };
  final closed = {
    'id': 'c',
    'title': 'Closed Job',
    'company': 'B',
    'description': 'y',
    'closed_at': '2026-11-01T00:00:00Z',
  };

  Future<void> board(WidgetTester t) async {
    t.view.physicalSize = const Size(600, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: JobBoardScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          fetchJobs: () async => [open, closed],
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('board shows open jobs by default with a mark', (t) async {
    await board(t);
    expect(find.text('Open Job'), findsOneWidget);
    expect(find.text('Closed Job'), findsNothing);
    expect(find.text('Dibuka'), findsWidgets);
  });

  testWidgets('status filter shows closed and all', (t) async {
    await board(t);
    await t.tap(find.byKey(const Key('job-status-filter')));
    await t.pumpAndSettle();
    await t.tap(find.text('Ditutup').last);
    await t.pumpAndSettle();
    expect(find.text('Closed Job'), findsOneWidget);
    expect(find.text('Open Job'), findsNothing);
    expect(find.byKey(const Key('job-status-closed')), findsOneWidget);

    await t.tap(find.byKey(const Key('job-status-filter')));
    await t.pumpAndSettle();
    await t.tap(find.text('Semua').last);
    await t.pumpAndSettle();
    expect(find.text('Closed Job'), findsOneWidget);
    expect(find.text('Open Job'), findsOneWidget);
  });

  testWidgets('closed job detail has a mark and no Apply', (t) async {
    t.view.physicalSize = const Size(600, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          job: {...closed, 'posted_by': 'other'},
          currentUser: ValueNotifier({'id': 'me'}),
          loadHasApplied: () async => false,
          loadApplicantCount: () async => 0,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('job-status-closed')), findsOneWidget);
    expect(find.byKey(const Key('apply-closed')), findsOneWidget);
    expect(find.text('Apply to this Job'), findsNothing);
  });
}
