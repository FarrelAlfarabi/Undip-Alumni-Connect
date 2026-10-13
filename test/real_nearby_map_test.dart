import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/map_config.dart';
import 'package:undip_alumni_connect/data/indonesian_cities.dart';
import 'package:undip_alumni_connect/widgets/nearby_map_view.dart'
    show AlumniPin;
import 'package:undip_alumni_connect/widgets/real_nearby_map.dart';

AlumniPin pin(String name, String city, int km) =>
    AlumniPin(profile: {'name': name, 'city': city}, km: km);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String myCity = 'Semarang',
    required List<AlumniPin> pins,
    ValueChanged<AlumniPin>? onPin,
    ValueChanged<String>? onCity,
  }) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RealNearbyMap(
            myCity: myCity,
            pins: pins,
            showTiles: false,
            onPinTap: onPin ?? (_) {},
            onCityTap: onCity ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  test('the real map is off unless the build turns it on', () {
    expect(kRealMap, isFalse);
    expect(kMapTileUrl, contains('{z}/{x}/{y}'));
  });

  group('city centres', () {
    test('every city has a centre inside Indonesia', () {
      for (final c in kIndonesianCities) {
        final p = cityCoordinates(c);
        expect(p, isNotNull, reason: c);
        expect(p!.$1, inInclusiveRange(-11.5, 6.5), reason: '$c latitude');
        expect(p.$2, inInclusiveRange(94.5, 141.5), reason: '$c longitude');
      }
    });

    test('no two cities share the same point', () {
      final seen = <String, String>{};
      for (final c in kIndonesianCities) {
        final p = cityCoordinates(c)!;
        final key = '${p.$1},${p.$2}';
        expect(seen[key], isNull, reason: '$c and ${seen[key]}');
        seen[key] = c;
      }
    });

    test('a few known cities are where they should be', () {
      // Rough checks against well known places, within about 0.3 degrees.
      void near(String city, double lat, double lng) {
        final p = cityCoordinates(city)!;
        expect((p.$1 - lat).abs(), lessThan(0.3), reason: city);
        expect((p.$2 - lng).abs(), lessThan(0.3), reason: city);
      }

      near('Jakarta', -6.2, 106.85);
      near('Semarang', -6.97, 110.42);
      near('Surabaya', -7.25, 112.75);
      near('Medan', 3.59, 98.67);
      near('Makassar', -5.15, 119.43);
      near('Jayapura', -2.53, 140.72);
    });
  });

  group('RealNearbyMap', () {
    testWidgets('one marker per city, with a count', (tester) async {
      await pump(
        tester,
        pins: [
          pin('A', 'Jakarta', 430),
          pin('B', 'Jakarta', 430),
          pin('C', 'Surabaya', 260),
        ],
      );
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const Key('map-city-Jakarta')), findsOneWidget);
      expect(find.byKey(const Key('map-city-Surabaya')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byKey(const Key('map-you')), findsOneWidget);
    });

    testWidgets('a city with one alumnus opens that profile', (tester) async {
      AlumniPin? tapped;
      await pump(
        tester,
        pins: [pin('C', 'Surabaya', 260)],
        onPin: (p) => tapped = p,
      );
      await tester.tap(find.byKey(const Key('map-city-Surabaya')));
      expect(tapped?.profile['name'], 'C');
    });

    testWidgets('a city with several alumni opens the city sheet', (
      tester,
    ) async {
      String? city;
      await pump(
        tester,
        pins: [pin('A', 'Jakarta', 430), pin('B', 'Jakarta', 430)],
        onCity: (c) => city = c,
      );
      await tester.tap(find.byKey(const Key('map-city-Jakarta')));
      expect(city, 'Jakarta');
    });

    testWidgets('alumni in the viewer\'s own city and a city with no known '
        'centre do not break the map', (tester) async {
      await pump(
        tester,
        pins: [
          pin('A', 'Semarang', 0),
          pin('B', 'Kudus', 50), // not in the list: left off the map
        ],
      );
      expect(find.byKey(const Key('map-city-Semarang')), findsOneWidget);
      expect(find.byKey(const Key('map-city-Kudus')), findsNothing);
      expect(find.byKey(const Key('map-you')), findsOneWidget);
    });

    testWidgets('no pins at all still draws a map', (tester) async {
      await pump(tester, pins: const []);
      expect(find.byType(FlutterMap), findsOneWidget);
    });
  });

  group('map buttons', () {
    MapCamera cam(WidgetTester tester) =>
        MapController.maybeOf(tester.element(find.byType(MarkerLayer)))!.camera;

    testWidgets('center goes to my city, show all fits everyone', (
      tester,
    ) async {
      await pump(
        tester,
        pins: [pin('A', 'Jakarta', 430), pin('C', 'Medan', 1400)],
      );
      final start = cam(tester);
      await tester.tap(find.byKey(const Key('map-center')));
      await tester.pump();
      final me = cityCoordinates('Semarang')!;
      expect(cam(tester).center.latitude, closeTo(me.$1, 0.01));
      expect(cam(tester).zoom, 10);

      await tester.tap(find.byKey(const Key('map-fit')));
      await tester.pump();
      expect(cam(tester).zoom, closeTo(start.zoom, 0.5));
    });

    testWidgets('nearest goes to the closest other city', (tester) async {
      await pump(
        tester,
        pins: [pin('A', 'Medan', 1400), pin('C', 'Yogyakarta', 110)],
      );
      await tester.tap(find.byKey(const Key('map-nearest')));
      await tester.pump();
      final y = cityCoordinates('Yogyakarta')!;
      expect(cam(tester).center.latitude, closeTo(y.$1, 0.01));
      expect(cam(tester).center.longitude, closeTo(y.$2, 0.01));
    });

    testWidgets('zoom buttons change the zoom by one step', (tester) async {
      await pump(tester, pins: [pin('A', 'Jakarta', 430)]);
      final z = cam(tester).zoom;
      await tester.tap(find.byKey(const Key('map-zoom-in')));
      await tester.pump();
      expect(cam(tester).zoom, z + 1);
      await tester.tap(find.byKey(const Key('map-zoom-out')));
      await tester.pump();
      expect(cam(tester).zoom, z);
    });

    testWidgets('center is off when my profile has no known city', (
      tester,
    ) async {
      await pump(tester, myCity: 'Kudus', pins: [pin('A', 'Jakarta', 430)]);
      final b = tester.widget<IconButton>(find.byKey(const Key('map-center')));
      expect(b.onPressed, isNull);
    });

    testWidgets('with nobody on the map, nearest is off', (tester) async {
      await pump(tester, pins: const []);
      final b = tester.widget<IconButton>(find.byKey(const Key('map-nearest')));
      expect(b.onPressed, isNull);
    });
  });
}
