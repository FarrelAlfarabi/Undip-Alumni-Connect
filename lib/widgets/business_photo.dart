import 'package:flutter/material.dart';

/// A business photo, cropped to a wide banner. Draws nothing when there is no
/// photo, so a business without one looks as before. A photo that fails to
/// load shows a quiet placeholder.
class BusinessPhoto extends StatelessWidget {
  const BusinessPhoto({super.key, required this.url, this.height = 140});

  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return const SizedBox.shrink();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) => Image.network(
              u,
              fit: BoxFit.cover,
              // Decode at the size it is drawn, not at full resolution.
              cacheWidth: (box.maxWidth * dpr).round(),
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (context, _, _) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
