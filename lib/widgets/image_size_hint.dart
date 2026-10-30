import 'package:flutter/material.dart';

enum ImageSizeKind { landscape, profile }

/// Short lines under a "Choose photo" button: the best size and the
/// accepted types. The one place this text is written.
class ImageSizeHint extends StatelessWidget {
  const ImageSizeHint([this.kind = ImageSizeKind.landscape, Key? key])
      : super(key: key);

  final ImageSizeKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (kind == ImageSizeKind.profile) {
      return Text(
        'Foto terbaik: persegi 1:1 (800 x 800 px), wajah di tengah. '
        'JPG, PNG atau WebP, maksimal 2 MB. Foto dipotong bulat di layar.',
        style: style,
      );
    }
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
