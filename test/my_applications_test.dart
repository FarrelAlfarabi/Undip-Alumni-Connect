import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/my_applications_screen.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<Map<String, dynamic>> rows,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MyApplicationsScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          fetch: (id) async => rows,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state', (tester) async {
    await pump(tester, []);
    expect(find.byKey(const Key('my-applications-empty')), findsOneWidget);
  });

  testWidgets('lists jobs with date and status', (tester) async {
    await pump(tester, [
      {
        'applied_at': '2026-11-20T10:00:00Z',
        'job': {'id': 'a', 'title': 'Analyst', 'company': 'Bank X'},
      },
      {
        'applied_at': '2026-11-10T10:00:00Z',
        'job': {
          'id': 'b',
          'title': 'Auditor',
          'company': 'KAP Y',
          'closed_at': '2026-11-15T00:00:00Z',
        },
      },
      {
        'applied_at': '2026-11-01T10:00:00Z',
        'job': {
          'id': 'c',
          'title': 'Staff',
          'company': 'PT Z',
          'hidden_at': '2026-11-02T00:00:00Z',
        },
      },
    ]);
    expect(find.textContaining('Masih dibuka'), findsOneWidget);
    expect(find.textContaining('Ditutup'), findsOneWidget);
    expect(find.textContaining('Tidak tersedia'), findsOneWidget);
    expect(find.textContaining('Dilamar 20 Nov 2026'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
  });

  testWidgets('a closed job still opens its detail', (tester) async {
    await pump(tester, [
      {
        'applied_at': '2026-11-10T10:00:00Z',
        'job': {
          'id': 'b',
          'title': 'Auditor',
          'company': 'KAP Y',
          'closed_at': '2026-11-15T00:00:00Z',
        },
      },
    ]);
    await tester.tap(find.byKey(const Key('application-b')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Auditor'), findsWidgets);
    expect(
      find.byType(MyApplicationsScreen, skipOffstage: false),
      findsOneWidget,
    );
  });
}
