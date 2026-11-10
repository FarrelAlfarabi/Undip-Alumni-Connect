import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../util/app_language.dart';
import 'banner_carousel.dart';

/// Wide and short, so a sponsor never takes much of the first screen.
const kSponsorAspectRatio = 16 / 5;

/// The sponsor carousel on Home, under the four tiles. Same behaviour as the
/// announcement carousel (slides by itself, swipe, dots), but a white card
/// with a hairline border so it never looks like an announcement. The label
/// "Disponsori" is fixed and cannot be changed by the admin. Shows nothing
/// when there is no sponsor.
class SponsorBanner extends StatelessWidget {
  const SponsorBanner({
    super.key,
    required this.items,
    required this.onOpen,
    this.onShown,
    this.autoAdvance = const Duration(seconds: 5),
  });

  /// Rows from `home_sponsors()`: id, name, image_url, link_url.
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> sponsor) onOpen;
  final void Function(Map<String, dynamic> sponsor)? onShown;
  final Duration autoAdvance;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return BannerCarousel(
      items: items,
      onOpen: onOpen,
      onShown: onShown,
      autoAdvance: autoAdvance,
      keyPrefix: 'sponsor',
      aspectRatio: kSponsorAspectRatio,
      cardBuilder: (context, item, onTap) =>
          _SponsorCard(item: item, onTap: onTap),
    );
  }
}

class _SponsorCard extends StatelessWidget {
  const _SponsorCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = item['name'] as String? ?? '';
    final url = item['image_url'] as String? ?? '';
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      container: true,
      button: true,
      label: '${tr('Disponsori')}: $name',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth: (800 * dpr).round(),
                  fadeInDuration: Duration.zero,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Text(
                    name.isEmpty
                        ? tr('Disponsori')
                        : '${tr('Disponsori')} · $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
