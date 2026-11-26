import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/job_board_screen.dart';
import 'package:undip_alumni_connect/screens/market_screen.dart';

import 'support/fake_business_api.dart';
import 'support/fake_marketplace_api.dart';

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
          marketplaceRepository: MarketplaceRepository(FakeApi()),
          businessRepository: BusinessRepository(FakeBusinessApi()),
          fetchJobs: () async => [],
        ),
      ),
    );
    expect(find.text('Jobs'), findsOneWidget);
    segment.value = 2;
    await tester.pump();
    expect(find.byType(JobBoardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a segment is only built and fetched once it is opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final segment = ValueNotifier<int>(0);
    final businessApi = FakeBusinessApi();
    var jobFetches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketScreen(
          currentUser: ValueNotifier({'id': 'me'}),
          segment: segment,
          marketplaceRepository: MarketplaceRepository(FakeApi()),
          businessRepository: BusinessRepository(businessApi),
          fetchJobs: () async {
            jobFetches++;
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Opened on Marketplace: Businesses and Jobs have not been asked for yet.
    expect(jobFetches, 0);
    expect(businessApi.calls, isEmpty);
    expect(find.byType(JobBoardScreen, skipOffstage: false), findsNothing);

    segment.value = 2;
    await tester.pumpAndSettle();
    expect(jobFetches, 1);

    // Going back and forth keeps what was built: no second request.
    segment.value = 0;
    await tester.pumpAndSettle();
    segment.value = 2;
    await tester.pumpAndSettle();
    expect(jobFetches, 1);
    expect(find.byType(JobBoardScreen, skipOffstage: false), findsOneWidget);
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

  group('Explore note', () {
    Future<ValueNotifier<int>> pumpMarket(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final segment = ValueNotifier<int>(0);
      await tester.pumpWidget(
        MaterialApp(
          home: MarketScreen(
            currentUser: ValueNotifier({'id': 'me'}),
            segment: segment,
            marketplaceRepository: MarketplaceRepository(FakeApi()),
            businessRepository: BusinessRepository(FakeBusinessApi()),
            fetchJobs: () async => [],
          ),
        ),
      );
      await tester.pump();
      return segment;
    }

    setUp(() => MarketScreen.noteClosed = false);

    testWidgets('shows under the segments on Marketplace and Businesses, '
        'not on Jobs', (tester) async {
      final segment = await pumpMarket(tester);
      final note = find.byKey(const Key('explore-note'));
      expect(note, findsOneWidget);
      expect(find.textContaining('tidak mengurus pembayaran'), findsOneWidget);
      segment.value = 1;
      await tester.pump();
      expect(note, findsOneWidget);
      segment.value = 2;
      await tester.pump();
      expect(note, findsNothing);
    });

    testWidgets('can be closed and stays closed while the app is open', (
      tester,
    ) async {
      final segment = await pumpMarket(tester);
      await tester.tap(find.byKey(const Key('explore-note-close')));
      await tester.pump();
      expect(find.byKey(const Key('explore-note')), findsNothing);
      segment.value = 1;
      await tester.pump();
      expect(find.byKey(const Key('explore-note')), findsNothing);
    });
  });
}
