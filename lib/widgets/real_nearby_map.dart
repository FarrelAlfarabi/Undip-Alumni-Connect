import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/map_config.dart';
import '../data/indonesian_cities.dart';
import 'nearby_map_view.dart' show AlumniPin;

/// Nearby Alumni on a real map. Each alumnus is placed at the CENTRE of the
/// city in their profile, never at a real position, and the app never asks
/// for device location. So alumni of one city share one marker with a count;
/// drawing them at different spots inside a city would pretend to know more
/// than we do.
///
/// Same inputs as the hand-drawn map ([NearbyMapView]) plus [onCityTap].
/// Alumni whose city has no known centre are left off the map (they still
/// show in the list and the city chips).
class RealNearbyMap extends StatelessWidget {
  const RealNearbyMap({
    super.key,
    required this.myCity,
    required this.pins,
    required this.onPinTap,
    required this.onCityTap,
    this.showTiles = true,
    this.height = 340,
  });

  final String myCity;
  final List<AlumniPin> pins;

  /// A city with exactly one alumnus was tapped.
  final ValueChanged<AlumniPin> onPinTap;

  /// A city with several alumni was tapped: open the city sheet.
  final ValueChanged<String> onCityTap;

  /// Tests turn the picture layer off (no network in tests).
  final bool showTiles;
  final double height;

  /// Alumni per city that has a known centre, in first-seen order.
  Map<String, List<AlumniPin>> get _byCity {
    final out = <String, List<AlumniPin>>{};
    for (final p in pins) {
      final city = p.profile['city'] as String? ?? '';
      if (cityCoordinates(city) == null) continue;
      out.putIfAbsent(city, () => []).add(p);
    }
    return out;
  }

  LatLng? _point(String city) {
    final c = cityCoordinates(city);
    return c == null ? null : LatLng(c.$1, c.$2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byCity = _byCity;
    final me = _point(myCity);
    final points = [for (final city in byCity.keys) _point(city)!, ?me];
    final land = theme.colorScheme.surfaceContainerHighest;
    final camera = points.length < 2
        ? MapOptions(
            initialCenter: points.isEmpty
                ? const LatLng(-2.5, 118) // middle of Indonesia
                : points.first,
            initialZoom: points.isEmpty ? 4 : 9,
            minZoom: 3,
            maxZoom: 12,
            backgroundColor: land,
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(56),
              maxZoom: 9,
            ),
            minZoom: 3,
            maxZoom: 12,
            backgroundColor: land,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        key: const Key('nearby-real-map'),
        height: height,
        child: FlutterMap(
          options: camera,
          children: [
            if (showTiles)
              TileLayer(
                urlTemplate: kMapTileUrl,
                userAgentPackageName: 'com.undip.alumni_connect',
              ),
            MarkerLayer(
              markers: [
                for (final e in byCity.entries)
                  Marker(
                    point: _point(e.key)!,
                    width: 96,
                    height: 62,
                    // The pin sits above the point; "You" sits below it.
                    alignment: e.key == myCity
                        ? Alignment.topCenter
                        : Alignment.center,
                    child: _CityMarker(
                      city: e.key,
                      count: e.value.length,
                      isMyCity: e.key == myCity,
                      onTap: () => e.value.length == 1
                          ? onPinTap(e.value.first)
                          : onCityTap(e.key),
                    ),
                  ),
                if (me != null)
                  Marker(
                    point: me,
                    width: 48,
                    height: 26,
                    alignment: Alignment.bottomCenter,
                    child: const _YouMarker(),
                  ),
              ],
            ),
            if (showTiles)
              SimpleAttributionWidget(
                source: const Text(kMapAttribution),
                backgroundColor: Colors.white70,
              ),
          ],
        ),
      ),
    );
  }
}

class _CityMarker extends StatelessWidget {
  const _CityMarker({
    required this.city,
    required this.count,
    required this.isMyCity,
    required this.onTap,
  });

  final String city;
  final int count;
  final bool isMyCity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$city, $count alumni',
      child: GestureDetector(
        key: Key('map-city-$city'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(blurRadius: 4, color: Colors.black26),
                ],
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YouMarker extends StatelessWidget {
  const _YouMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('map-you'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Text(
        'You',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
