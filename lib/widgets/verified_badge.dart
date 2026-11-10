import 'package:flutter/material.dart';

import '../util/app_language.dart';

/// Blue tick next to a business name. Shown only when an admin checked the
/// business NIB.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 18});

  final double size;

  /// Blue of the tick (fixed, so it reads the same in light and dark).
  static const Color blue = Color(0xFF1D9BF0);

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr('Usaha terverifikasi'),
    child: Tooltip(
      message: tr('Usaha terverifikasi'),
      child: Icon(Icons.verified, color: blue, size: size),
    ),
  );
}

/// A name with the tick after it when [verified].
class NameWithBadge extends StatelessWidget {
  const NameWithBadge({
    super.key,
    required this.name,
    required this.verified,
    this.style,
    this.maxLines,
    this.badgeSize = 18,
  });

  final String name;
  final bool verified;
  final TextStyle? style;
  final int? maxLines;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
    if (!verified) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: text),
        const SizedBox(width: 4),
        VerifiedBadge(size: badgeSize),
      ],
    );
  }
}
