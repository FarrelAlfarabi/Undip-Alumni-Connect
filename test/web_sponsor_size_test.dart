import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/widgets/sponsor_banner.dart';

import 'support/fake_home.dart';

Future<Size> _cardSize(WidgetTester t, double width) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SponsorBanner(
              items: [sponsorMap(1)],
              onOpen: (_) {},
              autoAdvance: const Duration(seconds: 3),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  return t.getSize(find.byKey(const Key('sponsor-pages')));
}

void main() {
  testWidgets('390: the card fills the width, as before', (t) async {
    final s = await _cardSize(t, 390);
    expect(s.width, 358);
  });

  testWidgets('1200 column: the card stays a banner, not a poster', (t) async {
    final s = await _cardSize(t, 1200);
    expect(s.width, lessThanOrEqualTo(kSponsorMaxWidth));
    expect(s.height, lessThanOrEqualTo(310));
  });

  testWidgets('1200 column: the card is centred', (t) async {
    await _cardSize(t, 1200);
    final r = t.getRect(find.byKey(const Key('sponsor-pages')));
    expect((r.left - (1200 - r.right)).abs(), lessThan(1));
  });
}
