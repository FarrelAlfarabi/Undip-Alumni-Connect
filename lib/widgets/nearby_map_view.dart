import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/city_coordinates.dart';

/// One alumnus on the map, plus their simulated distance from the viewer.
class AlumniPin {
  const AlumniPin({required this.profile, required this.km});

  final Map<String, dynamic> profile;
  final int km;
}

/// A Google-Maps-styled visualization of nearby alumni — every alumnus
/// gets their own marker (a small avatar "bubble," the same visual
/// language Google Maps uses for live people-sharing), laid out at their
/// city's real-world position so the map reads as an actual map of
/// Indonesia, not an abstract chart. Pinch/drag to zoom and pan like a
/// real map (via InteractiveViewer).
///
/// Still not a real map integration (no Google Maps SDK, no tiles, no
/// API key) and still never touches real GPS — see
/// nearby_alumni_screen.dart's doc comment and city_coordinates.dart for
/// why. Each city's coordinate is fixed and public; individual markers
/// within a city are spread with a small deterministic jitter so people
/// who share a city don't stack exactly on top of each other.
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

  static const _mapSize = Size(640, 400);
  static const _padding = 56.0;

  ({double minLat, double maxLat, double minLng, double maxLng}) get _bounds {
    final lats = cityCoordinates.values.map((c) => c.$1);
    final lngs = cityCoordinates.values.map((c) => c.$2);
    return (
      minLat: lats.reduce(math.min),
      maxLat: lats.reduce(math.max),
      minLng: lngs.reduce(math.min),
      maxLng: lngs.reduce(math.max),
    );
  }

  Offset _projectCity(String city) {
    final coord = cityCoordinates[city];
    if (coord == null) return _mapSize.center(Offset.zero);
    final b = _bounds;
    final latSpan = (b.maxLat - b.minLat).abs().clamp(0.0001, 1000.0);
    final lngSpan = (b.maxLng - b.minLng).abs().clamp(0.0001, 1000.0);
    final xFrac = (coord.$2 - b.minLng) / lngSpan;
    final yFrac = 1 - (coord.$1 - b.minLat) / latSpan;
    return Offset(
      _padding + xFrac * (_mapSize.width - _padding * 2),
      _padding + yFrac * (_mapSize.height - _padding * 2),
    );
  }

  Offset _jitter(String seed, double radius) {
    final h = seed.hashCode;
    final angle = (h % 360) * math.pi / 180;
    final r = radius * (0.35 + 0.65 * ((h ~/ 7) % 100) / 100);
    return Offset(r * math.cos(angle), r * math.sin(angle));
  }

  @override
  Widget build(BuildContext context) {
    final myPoint = _projectCity(myCity);
    final citiesPresent = <String>{
      myCity,
      ...pins.map((p) => p.profile['city'] as String? ?? ''),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 340,
        color: const Color(0xFFEDE8DE),
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(60),
          child: SizedBox(
            width: _mapSize.width,
            height: _mapSize.height,
            child: Stack(
              children: [
                CustomPaint(size: _mapSize, painter: _MapBackgroundPainter()),
                for (final city in cityCoordinates.keys)
                  if (citiesPresent.contains(city))
                    _CityLabel(city: city, position: _projectCity(city)),
                Positioned(
                  left: myPoint.dx - 20,
                  top: myPoint.dy - 20,
                  child: const _PersonMarker(initials: 'You', isMe: true),
                ),
                for (final pin in pins) _buildPin(pin),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPin(AlumniPin pin) {
    final city = pin.profile['city'] as String? ?? '';
    final base = _projectCity(city);
    final offset = _jitter(pin.profile['id'].toString(), 26);
    final point = base + offset;
    final name = pin.profile['name'] as String? ?? '?';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Positioned(
      left: point.dx - 16,
      top: point.dy - 16,
      child: Tooltip(
        message: pin.km == 0 ? '$name · same city' : '$name · ~${pin.km} km',
        child: GestureDetector(
          onTap: () => onPinTap(pin),
          child: _PersonMarker(initials: initials, isMe: false),
        ),
      ),
    );
  }
}

class _PersonMarker extends StatelessWidget {
  const _PersonMarker({required this.initials, required this.isMe});

  final String initials;
  final bool isMe;

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
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        isMe ? '★' : initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: isMe ? 16 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CityLabel extends StatelessWidget {
  const _CityLabel({required this.city, required this.position});

  final String city;
  final Offset position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: position.dx - 45,
      top: position.dy + 20,
      child: IgnorePointer(
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            city,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A light "road map" style background — solid land color, a faint grid
/// suggesting streets, and a soft green band suggesting Java's coastline
/// — purely decorative, not a real geographic rendering.
class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = const Color(0xFFEDE8DE);
    canvas.drawRect(Offset.zero & size, land);

    final grid = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final water = Paint()
      ..color = const Color(0xFFBFE0EE).withValues(alpha: 0.5);
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * 0.2,
        size.height * 0.7,
        size.width * 0.6,
        size.height * 0.5,
      ),
      water,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.7,
        -size.height * 0.2,
        size.width * 0.6,
        size.height * 0.5,
      ),
      water,
    );
  }

  @override
  bool shouldRepaint(covariant _MapBackgroundPainter oldDelegate) => false;
}
