import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One alumnus on the map, plus their simulated distance from the viewer.
class AlumniPin {
  const AlumniPin({required this.profile, required this.km});

  final Map<String, dynamic> profile;
  final int km;
}

/// Colors of the hand-painted map. The app has no dark theme, so only the
/// map follows the system brightness (see DECISIONS.md).
class MapPalette {
  const MapPalette._({
    required this.land,
    required this.water,
    required this.waterLine,
    required this.avenue,
    required this.grid,
    required this.labelText,
    required this.labelHalo,
    required this.markerBorder,
  });

  final Color land;
  final Color water;
  final Color waterLine;
  final Color avenue;
  final Color grid;
  final Color labelText;
  final Color labelHalo;
  final Color markerBorder;

  static const light = MapPalette._(
    land: Color(0xFFE8E2D4),
    water: Color(0xFFAFD8E8),
    waterLine: Color(0xFF8FC4D9),
    avenue: Color(0x8CFFFFFF),
    grid: Color(0x0A000000),
    labelText: Color(0xDD000000),
    labelHalo: Colors.white,
    markerBorder: Colors.white,
  );

  static const dark = MapPalette._(
    land: Color(0xFF232733),
    water: Color(0xFF173247),
    waterLine: Color(0xFF2F5B7C),
    avenue: Color(0x24FFFFFF),
    grid: Color(0x0DFFFFFF),
    labelText: Color(0xFFF2F2F2),
    labelHalo: Color(0xFF14161D),
    markerBorder: Color(0xFFF2F2F2),
  );

  static MapPalette of(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
}

const double _kViewportHeight = 340;
const double _kPadding = 44;
const double _kMarkerSpacing = 38;

/// A Google-Maps-styled visualization of nearby alumni — every alumnus
/// gets their own marker (a small avatar "bubble," the same visual
/// language Google Maps uses for live people-sharing) on a hand-painted
/// light "road map" background. Pinch/drag to zoom in further via
/// InteractiveViewer; the un-zoomed view always fits the whole map, so
/// nothing starts off-screen or cropped.
///
/// Still not a real map integration (no Google Maps SDK, no tiles, no
/// API key) and still never touches real GPS — see
/// nearby_alumni_screen.dart's doc comment for why.
///
/// Layout is a radial spread from "You" at center, not a literal
/// lat/lng projection: an earlier version placed each city at its real
/// coordinate, but Java's seed cities sit genuinely close together next
/// to Medan/Denpasar/Makassar, which are each roughly ten times
/// farther out — a real screenshot showed exactly what that does, every
/// marker crushed into one corner with the rest of the canvas empty.
/// Cities are now ranked by distance and spread at evenly-spaced angles
/// and increasing radius, so every city gets its own clearly separated
/// spot regardless of how close together they really are. Alumni who
/// share a city are further arranged in their own small non-overlapping
/// ring around that city's point (radius grows with the group size),
/// replacing an even earlier version's random jitter, which could and
/// did stack markers on top of each other at this data size — see
/// PROJECT_NOTES.md Session 24.
class NearbyMapView extends StatelessWidget {
  const NearbyMapView({
    super.key,
    required this.myCity,
    required this.pins,
    required this.onPinTap,
  });

  final String myCity;
  final List<AlumniPin> pins;
  final ValueChanged<AlumniPin> onPinTap;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        key: const Key('nearby-map'),
        height: _kViewportHeight,
        color: palette.land,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The un-zoomed canvas exactly fills the viewport, so the
            // whole map is visible by default; InteractiveViewer only
            // lets the viewer zoom *in* from there (minScale: 1).
            final mapSize = Size(constraints.maxWidth, _kViewportHeight);
            final layout = _MapLayout(
              myCity: myCity,
              pins: pins,
              mapSize: mapSize,
            );

            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(40),
              child: SizedBox(
                width: mapSize.width,
                height: mapSize.height,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: mapSize,
                      painter: _MapBackgroundPainter(palette),
                    ),
                    for (final marker in layout.markers)
                      _buildMarker(marker, palette),
                    _buildMarker(layout.myMarker, palette),
                    for (final label in layout.labels)
                      _CityLabel(
                        city: label.city,
                        position: label.position,
                        palette: palette,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMarker(_MarkerSpec marker, MapPalette palette) {
    final size = marker.isMe ? 40.0 : 32.0;
    final child = _PersonMarker(
      initials: marker.initials,
      isMe: marker.isMe,
      borderColor: palette.markerBorder,
    );

    return Positioned(
      left: marker.position.dx - size / 2,
      top: marker.position.dy - size / 2,
      child: marker.pin == null
          ? child
          : Tooltip(
              message: marker.pin!.km == 0
                  ? '${marker.name} · same city'
                  : '${marker.name} · ~${marker.pin!.km} km',
              child: GestureDetector(
                onTap: () => onPinTap(marker.pin!),
                child: child,
              ),
            ),
    );
  }
}

class _MarkerSpec {
  const _MarkerSpec({
    required this.position,
    required this.initials,
    required this.name,
    required this.isMe,
    this.pin,
  });

  final Offset position;
  final String initials;
  final String name;
  final bool isMe;
  final AlumniPin? pin;
}

class _LabelSpec {
  const _LabelSpec({required this.city, required this.position});

  final String city;
  final Offset position;
}

/// Computes every marker and label position once per build. Every other
/// city gets an evenly-spaced angle and a radius that increases with
/// distance rank (nearest = innermost), so no two cities ever land on
/// top of each other regardless of how close together they really are —
/// see the class doc comment above for why this isn't a literal lat/lng
/// projection. Alumni who share a city are then arranged in their own
/// small non-overlapping ring around that city's point (radius grows
/// with the group size), replacing an earlier version's random jitter,
/// which could and did stack markers on top of each other at this data
/// size — see PROJECT_NOTES.md Session 24.
class _MapLayout {
  _MapLayout({
    required this.myCity,
    required this.pins,
    required this.mapSize,
  }) {
    _compute();
  }

  final String myCity;
  final List<AlumniPin> pins;
  final Size mapSize;

  final List<_MarkerSpec> markers = [];
  final List<_LabelSpec> labels = [];
  late final _MarkerSpec myMarker;

  /// Local ring radius for [n] siblings clustered around one point, given
  /// a minimum center-to-center spacing of [minSpacing].
  static double _ringRadius(int n, double minSpacing) =>
      n <= 1 ? 0.0 : minSpacing / (2 * math.sin(math.pi / n));

  void _compute() {
    final byCity = <String, List<AlumniPin>>{};
    for (final pin in pins) {
      final city = pin.profile['city'] as String? ?? '';
      byCity.putIfAbsent(city, () => []).add(pin);
    }

    final center = mapSize.center(Offset.zero);
    final usableRadius = math.min(
      mapSize.width / 2 - _kPadding,
      mapSize.height / 2 - _kPadding,
    );

    // Alumni who share the viewer's own city ring around "You" — floored
    // well above the general sibling-spacing radius, since this ring
    // also has to clear the bigger 40px "You" marker at its center, not
    // just avoid overlapping its own neighbors.
    final myGroup = byCity[myCity] ?? const <AlumniPin>[];
    final myRingRadius = math.max(44.0, _ringRadius(myGroup.length, 40));

    final otherCities = byCity.keys.where((c) => c != myCity).toList()
      ..sort((a, b) => byCity[a]!.first.km.compareTo(byCity[b]!.first.km));

    // Every other city gets its own evenly-spaced angle and a radius
    // that increases with distance rank, clamped so nothing lands
    // outside the visible canvas — not a literal geographic projection
    // (see the class doc comment for why), just a guarantee that no two
    // cities' clusters ever land on top of each other.
    const step = 60.0;
    Offset cityCenter(int rank) {
      final angle = (2 * math.pi * rank / otherCities.length) - (math.pi / 2);
      final radius = math.min(usableRadius, myRingRadius + 34 + rank * step);
      return center +
          Offset(radius * math.cos(angle), radius * math.sin(angle));
    }

    for (var rank = 0; rank < otherCities.length; rank++) {
      final city = otherCities[rank];
      final base = cityCenter(rank);
      final group = byCity[city]!;
      final n = group.length;
      final ringRadius = _ringRadius(n, _kMarkerSpacing);
      for (var i = 0; i < n; i++) {
        final angle = (2 * math.pi * i / n) - (math.pi / 2);
        final offset = n <= 1
            ? Offset.zero
            : Offset(
                ringRadius * math.cos(angle),
                ringRadius * math.sin(angle),
              );
        final pin = group[i];
        final name = pin.profile['name'] as String? ?? '?';
        markers.add(
          _MarkerSpec(
            position: base + offset,
            initials: _initialsOf(name),
            name: name,
            isMe: false,
            pin: pin,
          ),
        );
      }
      labels.add(
        _LabelSpec(city: city, position: base - Offset(0, ringRadius + 22)),
      );
    }

    for (var i = 0; i < myGroup.length; i++) {
      final angle = (2 * math.pi * i / myGroup.length) - (math.pi / 2);
      final offset = Offset(
        myRingRadius * math.cos(angle),
        myRingRadius * math.sin(angle),
      );
      final pin = myGroup[i];
      final name = pin.profile['name'] as String? ?? '?';
      markers.add(
        _MarkerSpec(
          position: center + offset,
          initials: _initialsOf(name),
          name: name,
          isMe: false,
          pin: pin,
        ),
      );
    }

    myMarker = _MarkerSpec(
      position: center,
      initials: 'You',
      name: 'You',
      isMe: true,
    );
    labels.add(
      _LabelSpec(city: myCity, position: center - Offset(0, myRingRadius + 30)),
    );
  }

  static String _initialsOf(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w.isNotEmpty ? w[0] : '')
      .take(2)
      .join()
      .toUpperCase();
}

class _PersonMarker extends StatelessWidget {
  const _PersonMarker({
    required this.initials,
    required this.isMe,
    required this.borderColor,
  });

  final String initials;
  final bool isMe;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = isMe ? 40.0 : 32.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isMe ? theme.colorScheme.primary : theme.colorScheme.error,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: isMe
          ? const Icon(Icons.star_rounded, color: Colors.white, size: 20)
          : Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _CityLabel extends StatelessWidget {
  const _CityLabel({
    required this.city,
    required this.position,
    required this.palette,
  });

  final String city;
  final Offset position;
  final MapPalette palette;

  // A text halo (real Google Maps' label style) instead of a boxed pill.
  // The halo color follows the map palette so labels stay readable on
  // both the light and the dark map.
  List<Shadow> get _haloShadows => [
    Shadow(color: palette.labelHalo, offset: const Offset(-1.2, -1.2)),
    Shadow(color: palette.labelHalo, offset: const Offset(1.2, -1.2)),
    Shadow(color: palette.labelHalo, offset: const Offset(-1.2, 1.2)),
    Shadow(color: palette.labelHalo, offset: const Offset(1.2, 1.2)),
    Shadow(color: palette.labelHalo, blurRadius: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 70,
      top: position.dy - 9,
      child: IgnorePointer(
        child: SizedBox(
          width: 140,
          child: Text(
            city,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.labelText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              shadows: _haloShadows,
            ),
          ),
        ),
      ),
    );
  }
}

/// A light "road map" style background: solid land color, a sparse grid
/// suggesting streets with occasional wider "avenues," and a couple of
/// edge-anchored water shapes with a soft coastline stroke — purely
/// decorative, not a real geographic rendering.
class _MapBackgroundPainter extends CustomPainter {
  _MapBackgroundPainter(this.palette);

  final MapPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = palette.land;
    canvas.drawRect(Offset.zero & size, land);

    final water = Paint()..color = palette.water;
    final waterStroke = Paint()
      ..color = palette.waterLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final corner1 = Rect.fromLTWH(
      -size.width * 0.25,
      size.height * 0.62,
      size.width * 0.65,
      size.height * 0.6,
    );
    final corner2 = Rect.fromLTWH(
      size.width * 0.72,
      -size.height * 0.3,
      size.width * 0.55,
      size.height * 0.55,
    );
    canvas.drawOval(corner1, water);
    canvas.drawOval(corner1, waterStroke);
    canvas.drawOval(corner2, water);
    canvas.drawOval(corner2, waterStroke);

    final avenue = Paint()
      ..color = palette.avenue
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size.width * 0.15, 0),
      Offset(size.width * 0.35, size.height),
      avenue,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.55),
      avenue,
    );

    final grid = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _MapBackgroundPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
