import 'package:flutter/material.dart';

import '../lock/masking.dart' show initialsOf;

/// A person's photo in a circle. Falls back to their initials on a soft
/// background when there is no photo or it fails to load.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.url,
    required this.name,
    this.radius = 20,
  });

  final String? url;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = url;
    final initials = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.7,
        ),
      ),
    );
    if (u == null || u.isEmpty) return initials;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: Image.network(
          u,
          fit: BoxFit.cover,
          // Decode at the size it is drawn, not at full resolution.
          cacheWidth: (radius * 2 * dpr).round(),
          gaplessPlayback: true,
          semanticLabel: 'Foto $name',
          errorBuilder: (_, _, _) => initials,
        ),
      ),
    );
  }
}
