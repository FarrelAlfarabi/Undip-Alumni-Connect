import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One "cluster" on the radar map — every alumnus who shares a city, and
/// that city's simulated distance from the viewer.
class CityCluster {
  const CityCluster({
    required this.city,
    required this.km,
    required this.alumni,
  });

  final String city;
  final int km;
  final List<Map<String, dynamic>> alumni;
}

/// A radar-style visualization of nearby-alumni clusters, centered on
/// "you" — the demo version of Master Plan §3.4 item 6's "show a map of
/// nearby alumni" note. Deliberately not a real map: see
/// nearby_alumni_screen.dart's doc comment for why this project never
/// uses real GPS. Distance from center is proportional to a cluster's
/// simulated distance (lib/data/city_distances.dart); angle is a fixed,
/// deterministic spread across the cities present — not a real compass
/// bearing — chosen only so clusters don't overlap and stay put across
/// rebuilds.
class NearbyRadarMap extends StatelessWidget {
  const NearbyRadarMap({
    super.key,
    required this.myCity,
    required this.clusters,
    required this.onClusterTap,
  });

  final String myCity;
  final List<CityCluster> clusters;
  final ValueChanged<CityCluster> onClusterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedByCity = [...clusters]
      ..sort((a, b) => a.city.compareTo(b.city));
    final maxKm = clusters.isEmpty
        ? 1
        : clusters.map((c) => c.km).reduce(math.max);
    final maxKmSafe = maxKm == 0 ? 1 : maxKm;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, 340.0);
        final center = side / 2;
        final maxRadius = center - 40;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(side, side),
                  painter: _RadarRingsPainter(
                    color: theme.colorScheme.outlineVariant,
                    ringCount: 3,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primary,
                      child: Icon(
                        Icons.person,
                        size: 18,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('You · $myCity', style: theme.textTheme.labelSmall),
                  ],
                ),
                for (final entry in sortedByCity.asMap().entries)
                  _ClusterDot(
                    cluster: entry.value,
                    index: entry.key,
                    total: sortedByCity.length,
                    center: center,
                    maxRadius: maxRadius,
                    maxKm: maxKmSafe,
                    onTap: onClusterTap,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClusterDot extends StatelessWidget {
  const _ClusterDot({
    required this.cluster,
    required this.index,
    required this.total,
    required this.center,
    required this.maxRadius,
    required this.maxKm,
    required this.onTap,
  });

  final CityCluster cluster;
  final int index;
  final int total;
  final double center;
  final double maxRadius;
  final int maxKm;
  final ValueChanged<CityCluster> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final angle = (index * (2 * math.pi / total)) - (math.pi / 2);
    final radiusFraction = cluster.km == 0
        ? 0.24
        : 0.3 + 0.7 * (cluster.km / maxKm);
    final radius = maxRadius * radiusFraction;
    final dx = center + radius * math.cos(angle);
    final dy = center + radius * math.sin(angle);
    final dotSize = (28 + math.sqrt(cluster.alumni.length) * 8).clamp(
      28.0,
      56.0,
    );

    return Positioned(
      left: dx - dotSize / 2,
      top: dy - dotSize / 2,
      child: GestureDetector(
        onTap: () => onTap(cluster),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.secondary,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${cluster.alumni.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(cluster.city, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _RadarRingsPainter extends CustomPainter {
  _RadarRingsPainter({required this.color, required this.ringCount});

  final Color color;
  final int ringCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 40;
    for (var i = 1; i <= ringCount; i++) {
      canvas.drawCircle(center, maxRadius * i / ringCount, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarRingsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.ringCount != ringCount;
}
