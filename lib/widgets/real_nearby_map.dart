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
/// Buttons: center on my city, show all, nearest alumni, zoom in and out.
/// Alumni whose city has no known centre are left off the map (they still
/// show in the list and the city chips).
class RealNearbyMap extends StatefulWidget {
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

  @override
  State<RealNearbyMap> createState() => _RealNearbyMapState();
}

class _RealNearbyMapState extends State<RealNearbyMap> {
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Alumni per city that has a known centre, in first-seen order.
  Map<String, List<AlumniPin>> get _byCity {
    final out = <String, List<AlumniPin>>{};
    for (final p in widget.pins) {
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

  List<LatLng> get _allPoints => [
    for (final city in _byCity.keys) _point(city)!,
    ?_point(widget.myCity),
  ];

  /// The nearest city that has alumni, other than the viewer's own when
  /// another one exists. Null when nobody is on the map.
  String? get _nearestCity {
    final byCity = _byCity;
    if (byCity.isEmpty) return null;
    String? best;
    for (final e in byCity.entries) {
      if (e.key == widget.myCity && byCity.length > 1) continue;
      if (best == null || e.value.first.km < byCity[best]!.first.km) {
        best = e.key;
      }
    }
    return best;
  }

  void _fitAll() {
    final points = _allPoints;
    if (points.isEmpty) {
      _controller.move(_defaultCenter, 4);
    } else if (points.length == 1) {
      _controller.move(points.first, 9);
    } else {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(56),
          maxZoom: 9,
        ),
      );
    }
  }

  void _centerOnMe() {
    final me = _point(widget.myCity);
    if (me != null) _controller.move(me, 10);
  }

  void _goToNearest() {
    final city = _nearestCity;
    final p = city == null ? null : _point(city);
    if (p != null) _controller.move(p, 9);
  }

  void _zoomBy(double delta) {
    final cam = _controller.camera;
    _controller.move(
      cam.center,
      (cam.zoom + delta).clamp(_kMinZoom, _kMaxZoom),
    );
  }

  static const _defaultCenter = LatLng(-2.5, 118); // middle of Indonesia
  static const _kMinZoom = 3.0;
  static const _kMaxZoom = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byCity = _byCity;
    final me = _point(widget.myCity);
    final points = _allPoints;
    final land = theme.colorScheme.surfaceContainerHighest;
    final camera = points.length < 2
        ? MapOptions(
            initialCenter: points.isEmpty ? _defaultCenter : points.first,
            initialZoom: points.isEmpty ? 4 : 9,
            minZoom: _kMinZoom,
            maxZoom: _kMaxZoom,
            backgroundColor: land,
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(56),
              maxZoom: 9,
            ),
            minZoom: _kMinZoom,
            maxZoom: _kMaxZoom,
            backgroundColor: land,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        key: const Key('nearby-real-map'),
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: camera,
              children: [
                if (widget.showTiles)
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
                        alignment: e.key == widget.myCity
                            ? Alignment.topCenter
                            : Alignment.center,
                        child: _CityMarker(
                          city: e.key,
                          count: e.value.length,
                          isMyCity: e.key == widget.myCity,
                          onTap: () => e.value.length == 1
                              ? widget.onPinTap(e.value.first)
                              : widget.onCityTap(e.key),
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
                if (widget.showTiles)
                  SimpleAttributionWidget(
                    source: const Text(kMapAttribution),
                    backgroundColor: Colors.white70,
                  ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapButton(
                    buttonKey: const Key('map-center'),
                    icon: Icons.my_location,
                    tooltip: 'Center on my city',
                    onPressed: me == null ? null : _centerOnMe,
                  ),
                  _MapButton(
                    buttonKey: const Key('map-fit'),
                    icon: Icons.zoom_out_map,
                    tooltip: 'Show all alumni',
                    onPressed: _fitAll,
                  ),
                  _MapButton(
                    buttonKey: const Key('map-nearest'),
                    icon: Icons.near_me_outlined,
                    tooltip: 'Go to nearest alumni',
                    onPressed: _nearestCity == null ? null : _goToNearest,
                  ),
                  _MapButton(
                    buttonKey: const Key('map-zoom-in'),
                    icon: Icons.add,
                    tooltip: 'Zoom in',
                    onPressed: () => _zoomBy(1),
                  ),
                  _MapButton(
                    buttonKey: const Key('map-zoom-out'),
                    icon: Icons.remove,
                    tooltip: 'Zoom out',
                    onPressed: () => _zoomBy(-1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: IconButton(
          key: buttonKey,
          icon: Icon(icon, size: 20),
          tooltip: tooltip,
          color: Colors.black87,
          onPressed: onPressed,
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
