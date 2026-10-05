import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/widgets/nearby_map_view.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  Future<void> pump(WidgetTester tester, Brightness b) async {
    tester.platformDispatcher.platformBrightnessTestValue = b;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbyMapView(
            myCity: 'Semarang',
            pins: const [
              AlumniPin(profile: {'name': 'Budi Santoso'}, km: 0),
              AlumniPin(
                profile: {'name': 'Sari Dewi', 'city': 'Jakarta'},
                km: 450,
              ),
            ],
            onPinTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color land(WidgetTester tester) =>
      tester.widget<Container>(find.byKey(const Key('nearby-map'))).color!;

  testWidgets('light system theme uses the light map', (tester) async {
    await pump(tester, Brightness.light);
    expect(land(tester), MapPalette.light.land);
    expect(find.text('Semarang'), findsOneWidget);
    expect(find.text('BS'), findsOneWidget);
  });

  testWidgets('dark system theme uses the dark map', (tester) async {
    await pump(tester, Brightness.dark);
    expect(land(tester), MapPalette.dark.land);
    expect(find.text('Semarang'), findsOneWidget);
    expect(find.text('BS'), findsOneWidget);
    final label = tester.widget<Text>(find.text('Semarang'));
    expect(label.style!.color, MapPalette.dark.labelText);
  });

  test('palettes keep labels and markers readable (WCAG)', () {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2E2A5C));
    final fills = [const Color(0xFF2E2A5C), scheme.error];
    for (final p in [MapPalette.light, MapPalette.dark]) {
      expect(contrast(p.labelText, p.land), greaterThan(7));
      expect(contrast(p.labelText, p.water), greaterThan(4.5));
      expect(contrast(p.water, p.land), greaterThan(1.1));
      // A marker must stand out from the map by its fill or by its ring.
      for (final fill in fills) {
        for (final ground in [p.land, p.water]) {
          final standsOut =
              contrast(fill, ground) > 3 ||
              contrast(p.markerBorder, ground) > 3;
          expect(standsOut, isTrue, reason: '$fill on $ground');
        }
        // Initials are white on the marker fill.
        expect(contrast(Colors.white, fill), greaterThan(4.5));
      }
    }
  });
}
