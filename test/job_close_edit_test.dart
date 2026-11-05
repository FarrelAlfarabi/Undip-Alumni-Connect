import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/my_job_postings_screen.dart';

void main() {
  Future<List<(String, Map<String, dynamic>)>> pump(
    WidgetTester tester, {
    Object? closedAt,
  }) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <(String, Map<String, dynamic>)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MyJobPostingsScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          fetch: (id) async => [
            {
              'id': 'j1',
              'title': 'Analyst',
              'company': 'Bank X',
              'description': 'Kerja',
              'closed_at': closedAt,
            },
          ],
          rpc: (f, p) async => calls.add((f, p)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('poster closes a job', (tester) async {
    final calls = await pump(tester);
    await tester.tap(find.byKey(const Key('close-job-j1')));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'job_post_set_closed');
    expect(calls.single.$2, {'p_owner': 'me', 'p_job': 'j1', 'p_closed': true});
  });

  testWidgets('a closed job can be reopened', (tester) async {
    final calls = await pump(tester, closedAt: '2026-11-01T00:00:00Z');
    expect(find.textContaining('Ditutup'), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-job-j1')));
    await tester.pumpAndSettle();
    expect(calls.single.$2['p_closed'], false);
  });

  testWidgets('poster edits a job', (tester) async {
    final calls = await pump(tester);
    await tester.tap(find.byKey(const Key('edit-job-j1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('edit-title')),
      'Senior Analyst',
    );
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'job_post_update');
    expect(calls.single.$2['p_title'], 'Senior Analyst');
    expect(calls.single.$2['p_company'], 'Bank X');
  });
}
