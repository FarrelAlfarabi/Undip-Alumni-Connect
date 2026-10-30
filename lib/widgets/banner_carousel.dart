import 'dart:async';

import 'package:flutter/material.dart';

import '../data/marketplace_format.dart';
import '../theme.dart';

/// Hero height that follows the text size, so nothing clips: about 220 at
/// normal size, taller when the user enlarges text.
double heroHeightFor(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return 110 + 124 * scale.clamp(1.0, 2.0);
}

const _heroRadius = 20.0;

/// Auto-advancing banner carousel for Home. There is no image field on
/// announcements, so each banner is a text card: title, short excerpt, date.
/// Auto-advance pauses while a finger is down and does nothing for 0 or 1
/// item.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.items,
    required this.onOpen,
    this.autoAdvance = const Duration(seconds: 5),
    this.trailing,
  });

  /// Sits on the right of the dots row ("Lihat semua pengumuman").
  final Widget? trailing;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onOpen;
  final Duration autoAdvance;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(BannerCarousel old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length ||
        old.autoAdvance != widget.autoAdvance) {
      _page = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(widget.autoAdvance, (_) {
      if (!mounted || !_controller.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) return;
      final next = (_page + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: heroHeightFor(context),
          child: Listener(
            onPointerDown: (_) => _timer?.cancel(),
            onPointerUp: (_) => _startTimer(),
            onPointerCancel: (_) => _startTimer(),
            child: PageView.builder(
              key: const Key('banner-pages'),
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: KeyedSubtree(
                  key: Key('banner-hero-$i'),
                  child: _BannerCard(
                    item: items[i],
                    onTap: () => widget.onOpen(items[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: items.length > 1
                  ? Row(
                      key: const Key('banner-dots'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),

                              width: i == _page ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: i == _page
                                    ? AppTheme.black
                                    : scheme.outlineVariant,
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            if (widget.trailing != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: widget.trailing,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The yellow corner shape and the black rounded surface shared by the hero
/// and the welcome card. The shape sits behind the text.
class _HeroSurface extends StatelessWidget {
  const _HeroSurface({required this.child, this.onTap, this.semanticsLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        Positioned(
          top: -24,
          right: -24,
          child: ExcludeSemantics(
            child: Transform.rotate(
              angle: 0.5236,
              child: Container(
                key: const Key('hero-corner-shape'),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.yellow,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.all(18), child: child),
      ],
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(_heroRadius),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = DateTime.tryParse(item['created_at'] as String? ?? '');
    final body = (item['body'] as String? ?? '').trim();
    final title = item['title'] as String? ?? '';
    final onDark = Colors.white;
    return _HeroSurface(
      onTap: onTap,
      semanticsLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Keeps the first two rows clear of the corner shape.
          Padding(
            padding: const EdgeInsets.only(right: 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'IKAFE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: onDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (created != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          formatPostedDate(created),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: onDark.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: onDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onDark.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onTap,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Lihat detail'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.yellow,
              foregroundColor: AppTheme.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the carousel when there are no announcements yet.
class WelcomeBannerCard extends StatelessWidget {
  const WelcomeBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const Key('banner-welcome'),
      child: _HeroSurface(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(right: 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Lingkaran',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'News from Ikafe will show up here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
