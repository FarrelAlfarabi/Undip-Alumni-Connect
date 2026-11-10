import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../util/app_language.dart';
import 'banner_carousel.dart';

/// Wide and a little short, so the picture is easy to read without taking
/// the whole first screen (about 175 px high on a phone).
const kSponsorAspectRatio = 2.0;

/// The whole card: the yellow "Disponsori" bar plus the 2:1 picture below it.
const kSponsorCardAspectRatio = 1.75;

const _softYellow = Color(0xFFFFF6D6);

/// The sponsor carousel on Home, under the four tiles. Same behaviour as the
/// announcement carousel (slides by itself, swipe, dots), but a soft
/// yellow card with a yellow "Disponsori" bar on top, as in the approved
/// design, so it never looks like an announcement. The label
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
      aspectRatio: kSponsorCardAspectRatio,
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
        color: _softYellow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF0DC93)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppTheme.yellow,
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
                child: Row(
                  children: [
                    Text(
                      tr('Disponsori').toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (name.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.black,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: url.isEmpty
                    ? const SizedBox.shrink()
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        memCacheWidth: (800 * dpr).round(),
                        fadeInDuration: Duration.zero,
                        placeholder: (_, _) => const SizedBox.shrink(),
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
