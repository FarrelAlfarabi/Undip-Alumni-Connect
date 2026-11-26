import 'dart:async';

import '../util/app_language.dart';

import 'package:flutter/gestures.dart';
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
    this.cardBuilder,
    this.aspectRatio,
    this.keyPrefix = 'banner',
    this.onShown,
    this.requireVisible = false,
  });

  /// Called with an item each time it comes on screen: the first one after
  /// the first frame, then on every slide.
  final void Function(Map<String, dynamic> item)? onShown;

  /// When true, [onShown] and the auto-advance only run while the carousel is
  /// really in view: at least half of it inside the window, its tab and page
  /// on top. Sponsor views use this so a slide that nobody saw is not counted.
  final bool requireVisible;

  /// Builds a card other than the announcement card (the sponsor carousel
  /// uses this). [onTap] opens the item.
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> item,
    VoidCallback onTap,
  )?
  cardBuilder;

  /// When set, the pages have this width to height ratio instead of the hero
  /// height.
  final double? aspectRatio;

  /// Start of the widget keys (`-pages`, `-hero-N`, `-dots`), so two
  /// carousels on one screen can be told apart.
  final String keyPrefix;

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
  Timer? _visTimer;
  int _page = 0;
  int? _reportedPage;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportShown();
    });
    if (widget.requireVisible && widget.onShown != null) {
      _visTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _reportShown(),
      );
    }
  }

  /// True when at least half of the carousel is inside the window and nothing
  /// covers it (other tab, pushed page).
  bool get _inView {
    if (!widget.requireVisible) return true;
    if (!mounted) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return false;
    final view = View.of(context);
    final window = view.physicalSize / view.devicePixelRatio;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final seen = rect.intersect(Offset.zero & window);
    if (seen.isEmpty) return false;
    if (seen.height < rect.height / 2 || seen.width < rect.width / 2) {
      return false;
    }
    // A tab kept alive by an IndexedStack, or a page pushed on top, does not
    // take hits at the carousel's centre.
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, seen.center, view.viewId);
    return result.path.any((e) => e.target == box);
  }

  void _reportShown() {
    final items = widget.items;
    if (items.isEmpty || _page >= items.length) return;
    if (_reportedPage == _page || !_inView) return;
    _reportedPage = _page;
    widget.onShown?.call(items[_page]);
  }

  @override
  void didUpdateWidget(BannerCarousel old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length ||
        old.autoAdvance != widget.autoAdvance) {
      _page = 0;
      _reportedPage = null;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _visTimer?.cancel();
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
      if (!_inView) return;
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
    final prefix = widget.keyPrefix;
    final pages = Listener(
      onPointerDown: (_) => _timer?.cancel(),
      onPointerUp: (_) => _startTimer(),
      onPointerCancel: (_) => _startTimer(),
      // A mouse can drag too (laptop). Flutter only lets touch drag a
      // PageView by default.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: PageView.builder(
          key: Key('$prefix-pages'),
          controller: _controller,
          itemCount: items.length,
          onPageChanged: (i) {
            setState(() => _page = i);
            _reportShown();
          },
          itemBuilder: (context, i) {
            void open() => widget.onOpen(items[i]);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: KeyedSubtree(
                key: Key('$prefix-hero-$i'),
                child:
                    widget.cardBuilder?.call(context, items[i], open) ??
                    _BannerCard(item: items[i], onTap: open),
              ),
            );
          },
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.aspectRatio != null
            ? AspectRatio(aspectRatio: widget.aspectRatio!, child: pages)
            : SizedBox(height: heroHeightFor(context), child: pages),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: items.length > 1
                  ? Row(
                      key: Key('$prefix-dots'),
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
              Flexible(
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
            label: Text(tr('Lihat detail')),
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
                  tr('Welcome to Lingkaran'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr('News from Ikafe will show up here.'),
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
