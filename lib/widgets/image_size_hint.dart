import 'package:flutter/material.dart';

enum ImageSizeKind { landscape, profile }

/// The best photo size, shown under every Choose photo button.
class ImageSizeHint extends StatelessWidget {
  const ImageSizeHint(this.kind, {super.key});

  final ImageSizeKind kind;

  static const _texts = {
    ImageSizeKind.landscape:
        'Foto terbaik: landscape 3:2 (1200 x 800 px), objek di tengah. '
        'JPG, PNG atau WebP, maksimal 2 MB. Tepi foto bisa terpotong di layar.',
    ImageSizeKind.profile:
        'Foto terbaik: persegi 1:1 (800 x 800 px), wajah di tengah. '
        'JPG, PNG atau WebP, maksimal 2 MB. Foto dipotong bulat di layar.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _texts[kind]!,
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
