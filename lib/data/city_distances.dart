import 'dart:math' as math;

import 'indonesian_cities.dart';

/// Static straight-line distances (km, approximate) between the cities
/// used in the seed data. Powers the "Nearby Alumni" demo feature.
///
/// DEMO SCOPE: this is a hardcoded lookup table, not real geolocation.
/// The app never requests location permission and never reads a device's
/// actual position — "nearby" is simulated from each alumnus's seeded
/// `city` field. See the migration that added that column for why real
/// location-sharing was deliberately left out of this demo.
const Map<String, Map<String, int>> _cityDistancesKm = {
  'Jakarta': {
    'Jakarta': 0,
    'Semarang': 430,
    'Surabaya': 660,
    'Bandung': 120,
    'Yogyakarta': 430,
    'Denpasar': 880,
    'Medan': 1400,
    'Makassar': 1140,
  },
  'Semarang': {
    'Jakarta': 430,
    'Semarang': 0,
    'Surabaya': 260,
    'Bandung': 330,
    'Yogyakarta': 110,
    'Denpasar': 660,
    'Medan': 1400,
    'Makassar': 780,
  },
  'Surabaya': {
    'Jakarta': 660,
    'Semarang': 260,
    'Surabaya': 0,
    'Bandung': 600,
    'Yogyakarta': 250,
    'Denpasar': 330,
    'Medan': 1900,
    'Makassar': 570,
  },
  'Bandung': {
    'Jakarta': 120,
    'Semarang': 330,
    'Surabaya': 600,
    'Bandung': 0,
    'Yogyakarta': 330,
    'Denpasar': 750,
    'Medan': 1500,
    'Makassar': 1150,
  },
  'Yogyakarta': {
    'Jakarta': 430,
    'Semarang': 110,
    'Surabaya': 250,
    'Bandung': 330,
    'Yogyakarta': 0,
    'Denpasar': 550,
    'Medan': 1650,
    'Makassar': 850,
  },
  'Denpasar': {
    'Jakarta': 880,
    'Semarang': 660,
    'Surabaya': 330,
    'Bandung': 750,
    'Yogyakarta': 550,
    'Denpasar': 0,
    'Medan': 2100,
    'Makassar': 630,
  },
  'Medan': {
    'Jakarta': 1400,
    'Semarang': 1400,
    'Surabaya': 1900,
    'Bandung': 1500,
    'Yogyakarta': 1650,
    'Denpasar': 2100,
    'Medan': 0,
    'Makassar': 2050,
  },
  'Makassar': {
    'Jakarta': 1140,
    'Semarang': 780,
    'Surabaya': 570,
    'Bandung': 1150,
    'Yogyakarta': 850,
    'Denpasar': 630,
    'Makassar': 0,
    'Medan': 2050,
  },
};

/// Approximate distance in km between two seeded cities, or null if either
/// city isn't in the demo's lookup table.
int? approxDistanceKm(String? from, String? to) {
  if (from == null || to == null) return null;
  final known = _cityDistancesKm[from]?[to];
  if (known != null) return known;
  if (from == to) return cityCoordinates(from) == null ? null : 0;
  final a = cityCoordinates(from);
  final b = cityCoordinates(to);
  if (a == null || b == null) return null;
  return _greatCircleKm(a, b);
}

/// Straight-line distance between two (lat, lng) points, rounded to 10 km.
int _greatCircleKm((double, double) a, (double, double) b) {
  const rad = math.pi / 180;
  final dLat = (b.$1 - a.$1) * rad;
  final dLng = (b.$2 - a.$2) * rad;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.$1 * rad) *
          math.cos(b.$1 * rad) *
          math.pow(math.sin(dLng / 2), 2);
  final km = 2 * 6371 * math.asin(math.sqrt(h));
  return (km / 10).round() * 10;
}

/// Cities the profile's City picker offers: every Indonesian city. Each one
/// has a distance to every other, so a chosen city always works in Nearby.
List<String> get kNearbyCities => kIndonesianCities;
