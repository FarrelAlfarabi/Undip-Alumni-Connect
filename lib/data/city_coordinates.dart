/// Approximate real-world lat/lng for the cities used in seed data.
///
/// DEMO SCOPE: these are fixed, hardcoded coordinates for each *city*,
/// used only to lay the Nearby Alumni map (nearby_map_view.dart) out in
/// roughly the right relative positions so it reads as a real map of
/// Indonesia — they are not tied to any device's actual location. No
/// alumnus's real position is ever read or stored; see
/// nearby_alumni_screen.dart's doc comment for the full reasoning (same
/// as lib/data/city_distances.dart).
const Map<String, (double lat, double lng)> cityCoordinates = {
  'Jakarta': (-6.2088, 106.8456),
  'Semarang': (-6.9932, 110.4203),
  'Surabaya': (-7.2575, 112.7521),
  'Bandung': (-6.9175, 107.6191),
  'Yogyakarta': (-7.7956, 110.3695),
  'Denpasar': (-8.6705, 115.2126),
  'Medan': (3.5952, 98.6722),
  'Makassar': (-5.1477, 119.4327),
};
