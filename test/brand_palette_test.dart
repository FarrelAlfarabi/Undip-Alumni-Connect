import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/welcome_screen.dart';
import 'package:undip_alumni_connect/theme.dart';
import 'package:undip_alumni_connect/widgets/brand_lockup.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The palette comes from the Ikafe UNDIP logo: yellow, black and blue.
void main() {
  test('palette uses the Ikafe UNDIP yellow, black and blue', () {
    expect(AppTheme.yellow, const Color(0xFFFFC400));
    expect(AppTheme.black, const Color(0xFF141414));
    expect(AppTheme.blue, const Color(0xFF0073B1));
  });

  test('theme maps the palette onto the color scheme', () {
    final scheme = AppTheme.light().colorScheme;
    expect(scheme.primary, AppTheme.black);
    expect(scheme.onPrimary, Colors.white);
    expect(scheme.surface, AppTheme.paper);
  });

  test('filled buttons are yellow with black text', () {
    final style = AppTheme.light().filledButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), AppTheme.yellow);
    expect(style.foregroundColor!.resolve({}), AppTheme.black);
  });

  test('text links are blue', () {
    final style = AppTheme.light().textButtonTheme.style!;
    expect(style.foregroundColor!.resolve({}), AppTheme.blue);
  });

  test('danger is red and white text on it meets 4.5:1', () {
    expect(AppTheme.danger, const Color(0xFFD93025));
    expect(_ratio(Colors.white, AppTheme.danger), greaterThanOrEqualTo(4.5));
  });

  test('badge is danger with white text', () {
    final badge = AppTheme.light().badgeTheme;
    expect(badge.backgroundColor, AppTheme.danger);
    expect(badge.textColor, Colors.white);
  });

  test('nav bar has a yellow stadium indicator and always shows labels', () {
    final nav = AppTheme.light().navigationBarTheme;
    expect(nav.backgroundColor, Colors.white);
    expect(nav.indicatorColor, AppTheme.yellow);
    expect(nav.indicatorShape, isA<StadiumBorder>());
    expect(nav.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
    expect(nav.height, 72);
    expect(nav.surfaceTintColor, Colors.transparent);
    final selected = nav.labelTextStyle!.resolve({WidgetState.selected})!;
    final idle = nav.labelTextStyle!.resolve({})!;
    expect(selected.fontSize, greaterThanOrEqualTo(12));
    expect(idle.fontSize, greaterThanOrEqualTo(12));
    expect(selected.fontWeight, FontWeight.w700);
    expect(idle.fontWeight, FontWeight.w500);
    expect(
      nav.iconTheme!.resolve({WidgetState.selected})!.color,
      AppTheme.black,
    );
    expect(
      nav.iconTheme!.resolve({})!.color,
      AppTheme.light().colorScheme.onSurfaceVariant,
    );
  });

  test('buttons are pills; a black pill style exists', () {
    final theme = AppTheme.light();
    expect(
      theme.filledButtonTheme.style!.shape!.resolve({}),
      isA<StadiumBorder>(),
    );
    expect(
      theme.filledButtonTheme.style!.textStyle!.resolve({})!.fontWeight,
      FontWeight.w700,
    );
    final black = AppTheme.blackPillButton;
    expect(black.backgroundColor!.resolve({}), AppTheme.black);
    expect(black.foregroundColor!.resolve({}), Colors.white);
    expect(black.shape!.resolve({}), isA<StadiumBorder>());
    final link = theme.textButtonTheme.style!;
    expect(link.textStyle!.resolve({})!.fontWeight, FontWeight.w600);
  });

  test('cards are white, radius 16, hairline border, flat', () {
    final card = AppTheme.light().cardTheme;
    expect(card.color, Colors.white);
    expect(card.elevation, 0);
    final shape = card.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(16));
    expect(shape.side.color, AppTheme.hairline);
    expect(shape.side.width, 1);
  });

  test('every text pairing meets WCAG AA 4.5:1', () {
    final scheme = AppTheme.light().colorScheme;
    final pairs = <String, double>{
      'black on yellow': _ratio(AppTheme.black, AppTheme.yellow),
      'yellow on black': _ratio(AppTheme.yellow, AppTheme.black),
      'white on blue': _ratio(Colors.white, AppTheme.blue),
      'blue on paper': _ratio(AppTheme.blue, AppTheme.paper),
      'blue on raised paper': _ratio(AppTheme.blue, AppTheme.paperRaised),
      'ink on paper': _ratio(AppTheme.ink, AppTheme.paper),
      'ink on raised paper': _ratio(AppTheme.ink, AppTheme.paperRaised),
      'white on primary': _ratio(scheme.onPrimary, scheme.primary),
      'secondary on paper': _ratio(scheme.secondary, AppTheme.paper),
      'secondary on raised paper': _ratio(
        scheme.secondary,
        AppTheme.paperRaised,
      ),
      'on primaryContainer': _ratio(
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
      'on secondaryContainer': _ratio(
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ),
    };
    pairs.forEach((name, r) {
      expect(r, greaterThanOrEqualTo(4.5), reason: '$name is $r');
    });
  });

  test('surfaces are neutral grey, no cream or blue tint', () {
    final scheme = AppTheme.light().colorScheme;
    int spread(Color c) {
      final v = [c.r, c.g, c.b].map((x) => (x * 255).round()).toList()..sort();
      return v.last - v.first;
    }

    for (final c in [
      scheme.surface,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.outlineVariant,
    ]) {
      expect(spread(c), lessThanOrEqualTo(6), reason: '$c is tinted');
    }
    expect(scheme.surface, isNot(const Color(0xFFF8F6F1)));
  });

  test('the old indigo and brass are gone from the theme', () {
    final scheme = AppTheme.light().colorScheme;
    for (final c in [scheme.primary, scheme.secondary, scheme.surface]) {
      expect(c, isNot(const Color(0xFF2E2A5C)));
      expect(c, isNot(const Color(0xFF7F5815)));
    }
  });

  test('the logo asset is the sharp PNG and the old JPG is gone', () {
    expect(kIkafeLogoAsset, 'assets/brand/ikafe_undip_logo.png');
    expect(File('assets/brand/ikafe_undip_logo.jpg').existsSync(), isFalse);
  });

  test('the logo asset exists and is declared in pubspec', () {
    expect(File(kIkafeLogoAsset).existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/brand/'));
  });

  testWidgets('lockup shows the logo and the app title', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: BrandLockup()),
      ),
    );
    expect(find.text('Lingkaran'), findsOneWidget);
    expect(find.text('by Ikafe UNDIP'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    expect((resized.imageProvider as AssetImage).assetName, kIkafeLogoAsset);
    expect(resized.height, isNotNull);
    expect(find.bySemanticsLabel('Ikafe UNDIP'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the logo chip is white so its black letters stay readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: IkafeLogo()),
        ),
      ),
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(IkafeLogo),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, Colors.white);
  });

  testWidgets('the Welcome screen shows the Ikafe logo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const WelcomeScreen()),
    );
    expect(find.byType(IkafeLogo), findsOneWidget);
  });
}
