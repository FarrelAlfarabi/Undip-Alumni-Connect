import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// One photo box for products, businesses and jobs: 3:2, cropped to fill,
/// with the soft yellow placeholder while it loads or when it fails.
class AppPhoto extends StatelessWidget {
  const AppPhoto({
    super.key,
    required this.url,
    this.aspectRatio = 3 / 2,
    this.semanticLabel,
    this.radius = 12,
  });

  final String url;
  final double aspectRatio;

  /// Read out by screen readers, usually the name of the product or business.
  final String? semanticLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final soft = Theme.of(context).colorScheme.secondaryContainer;
    Widget placeholder() => ColoredBox(
      color: soft,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(
          builder: (context, box) => Semantics(
            label: semanticLabel,
            image: true,
            excludeSemantics: semanticLabel != null,
            // Cached on the device, so photos are not downloaded again.
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              // Decode at the size it is drawn, not at full resolution.
              memCacheWidth: box.hasBoundedWidth
                  ? (box.maxWidth * dpr).round()
                  : (600 * dpr).round(),
              fadeInDuration: Duration.zero,
              useOldImageOnUrlChange: true,
              placeholder: (_, _) => placeholder(),
              errorWidget: (_, _, _) => placeholder(),
            ),
          ),
        ),
      ),
    );
  }
}
