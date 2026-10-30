import 'package:flutter/material.dart';

/// Two short lines shown directly under every "Choose photo" button, so a
/// person knows the best size before picking.
class ImageSizeHint extends StatelessWidget {
  const ImageSizeHint({super.key});

  static const String sizeLine = 'Foto terbaik: landscape 3:2 (1200 x 800 px).';
  static const String typeLine = 'JPG, PNG atau WebP, maksimal 2 MB.';

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sizeLine, style: style),
          Text(typeLine, style: style),
        ],
      ),
    );
  }
}
