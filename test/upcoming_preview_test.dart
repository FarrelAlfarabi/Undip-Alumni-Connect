import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/marketplace_repository.dart';
import 'package:undip_alumni_connect/screens/home_screen.dart';
import 'package:undip_alumni_connect/widgets/upcoming_section.dart';

import 'support/fake_home.dart';
import 'support/fake_marketplace_api.dart';

Future<void> pumpHome(WidgetTester tester, {double width = 390}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(
        currentUser: ValueNotifier({'id': 'me', 'name': 'Ahmad Ramadhan'}),
        onOpenDirectory: () {},
        pages: fakePages(),
        api: FakeHomeApi(),
        marketplaceRepository: MarketplaceRepository(FakeApi()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('upcoming-section')));
  await tester.pump();
}

void main() {
  const tiles = {
    'preview-events': 'Events',
    'preview-mentoring': 'Mentoring',
    'preview-business': 'Business directory',
  };

  testWidgets('three tiles, each with a Preview badge', (tester) async {
    await pumpHome(tester);
    for (final e in tiles.entries) {
      final tile = find.byKey(Key(e.key));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text(e.value)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.text('Preview')),
        findsOneWidget,
      );
    }
  });

  testWidgets('tapping opens the info sheet and navigates nowhere', (
    tester,
  ) async {
    await pumpHome(tester);
    for (final e in tiles.entries) {
      await tester.tap(find.byKey(Key(e.key)));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('preview-sheet'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text(e.value)),
        findsOneWidget,
      );
      expect(find.text(kPreviewNotice), findsOneWidget);
      // Still on the same route: Home is the only page, nothing was pushed.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('PAGE '), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    }
  });

  testWidgets('no money features, dates or promises in the section', (
    tester,
  ) async {
    await pumpHome(tester);
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('upcoming-section')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join(' ')
        .toLowerCase();
    for (final banned in [
      'donation',
      'crowdfund',
      'merch',
      'scholarship',
      'fee',
      'price',
      'coming soon',
      '2026',
      '2027',
    ]) {
      expect(texts.contains(banned), isFalse, reason: banned);
    }
  });

  testWidgets('no overflow at 320 px wide', (tester) async {
    await pumpHome(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
