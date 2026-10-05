import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/marketplace_screen.dart';
import 'package:undip_alumni_connect/theme.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('brand colors meet WCAG AA 4.5:1 for text', () {
    const onLight = Color(0xFFFAF6EA);
    for (final bg in [
      AppTheme.paper,
      AppTheme.paperRaised,
      const Color(0xFFF1E4C9),
    ]) {
      expect(
        _ratio(AppTheme.gold, bg),
        greaterThanOrEqualTo(4.5),
        reason: '$bg',
      );
    }
    expect(_ratio(onLight, AppTheme.gold), greaterThanOrEqualTo(4.5));
    expect(_ratio(onLight, AppTheme.indigo), greaterThanOrEqualTo(4.5));
    expect(_ratio(AppTheme.ink, AppTheme.paper), greaterThanOrEqualTo(4.5));
    expect(_ratio(AppTheme.indigo, AppTheme.paper), greaterThanOrEqualTo(4.5));
  });

  testWidgets('listing photo has a text alternative when given a label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListingImage(url: '', semanticLabel: 'Photo of Kopi Susu'),
        ),
      ),
    );
    // Empty url shows the placeholder, so check the network branch directly.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListingImage(
            url: 'https://example.invalid/x.jpg',
            semanticLabel: 'Photo of Kopi Susu',
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Photo of Kopi Susu'), findsOneWidget);
    handle.dispose();
  });
}
