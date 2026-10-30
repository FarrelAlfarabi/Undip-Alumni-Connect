import 'package:flutter/material.dart';

/// Two short lines under a "Choose photo" button: the best size and the
/// accepted types. The one place this text is written.
class ImageSizeHint extends StatelessWidget {
  const ImageSizeHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Foto terbaik: landscape 3:2 (1200 x 800 px).', style: style),
          Text('JPG, PNG atau WebP, maksimal 2 MB.', style: style),
        ],
      ),
    );
  }
}
