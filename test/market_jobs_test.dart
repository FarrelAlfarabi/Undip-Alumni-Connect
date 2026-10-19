import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/job_board_screen.dart';
import 'package:undip_alumni_connect/screens/market_screen.dart';

void main() {
  testWidgets('Market has a Jobs segment that shows the job board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final segment = ValueNotifier<int>(0);
    await tester.pumpWidget(
      MaterialApp(
        home: MarketScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          segment: segment,
        ),
      ),
    );
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.byType(JobBoardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded job board has no second app bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobBoardScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          embedded: true,
          fetchJobs: () async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Post a Job'), findsOneWidget);
  });
}
