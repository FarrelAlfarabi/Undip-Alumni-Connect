import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../util/app_language.dart';
import 'banner_carousel.dart';

/// The picture is 16:9, the usual photo and banner shape, so most sponsor
/// images fit with little trimming (Farrel, 16 Nov 2026: 2:1 was too thin).
/// About 200 px high on a phone.
const kSponsorAspectRatio = 16 / 9;

/// The whole card: the yellow "Disponsori" bar plus the 16:9 picture below.
const kSponsorCardAspectRatio = 1.6;

/// Widest the card gets. On a phone it fills the width as before; on a wide
/// screen it stops here (about 300 px high) and sits centred, so it stays a
/// banner and does not take the whole first screen.
const double kSponsorMaxWidth = 480;

/// Wide, low strip: the small caption above a picture shown whole (not
/// cropped), on no background, so a logo with a transparent background sits
/// straight on the page.
const kSeamlessAspectRatio = 2.2;

const _softYellow = Color(0xFFFFF6D6);

/// The sponsor carousel on Home, under the four tiles. Same behaviour as the
/// announcement carousel (slides by itself, swipe, dots), but a soft
/// yellow card with a yellow "Disponsori" bar on top, as in the approved
/// design, so it never looks like an announcement. The label
/// "Disponsori" is fixed and cannot be changed by the admin. Shows nothing
/// when there is no sponsor.
/// Most slides the carousel shows. The database function `home_sponsors()`
/// applies the same limit.
const int kMaxSponsorSlides = 10;

class SponsorBanner extends StatelessWidget {
  const SponsorBanner({
    super.key,
    required this.items,
    required this.onOpen,
    this.onShown,
    this.autoAdvance = const Duration(seconds: 5),
    this.maxWidth = kSponsorMaxWidth,
    this.seamless = false,
    this.captionColor,
  });

  /// Rows from `home_sponsors()`: id, name, image_url, link_url.
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> sponsor) onOpen;
  final void Function(Map<String, dynamic> sponsor)? onShown;
  final Duration autoAdvance;

  /// Widest the card gets (Home uses the default; start screens go smaller).
  final double maxWidth;

  /// Start-screen look (Welcome, PIN lock): no border, no yellow bar, no card
  /// colour. A small "Disponsori" caption and the picture, so it blends into
  /// the page. Home keeps the card.
  final bool seamless;

  /// Caption colour in the seamless look (light text on the black lock screen).
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final carousel = BannerCarousel(
      items: items.take(kMaxSponsorSlides).toList(),
      onOpen: onOpen,
      onShown: onShown,
      requireVisible: true,
      autoAdvance: autoAdvance,
      keyPrefix: 'sponsor',
      aspectRatio: seamless ? kSeamlessAspectRatio : kSponsorCardAspectRatio,
      cardBuilder: (context, item, onTap) => seamless
          ? _SeamlessSponsor(
              item: item,
              onTap: onTap,
              captionColor: captionColor,
            )
          : _SponsorCard(item: item, onTap: onTap),
    );
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: carousel,
      ),
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

/// The sponsor without a card: a small caption, then the picture with soft
/// corners. No border, no background.
class _SeamlessSponsor extends StatelessWidget {
  const _SeamlessSponsor({
    required this.item,
    required this.onTap,
    this.captionColor,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = item['name'] as String? ?? '';
    final url = item['image_url'] as String? ?? '';
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final color =
        captionColor ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8);
    return Semantics(
      container: true,
      button: true,
      label: '${tr('Disponsori')}: $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                tr('Disponsori').toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: url.isEmpty
                  ? const SizedBox.shrink()
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      memCacheWidth: (800 * dpr).round(),
                      fadeInDuration: Duration.zero,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
