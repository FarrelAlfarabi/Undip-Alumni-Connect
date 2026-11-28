import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../util/app_language.dart';
import 'sponsor_banner.dart' show kMaxSponsorSlides;

/// Columns for [count] sponsors. Few sponsors get big tiles in one row; up to
/// 10 fit in at most 3 rows of 4 so the grid stays short on the PIN screen.
int sponsorGridColumns(int count) {
  if (count <= 4) return count < 1 ? 1 : count;
  if (count <= 6) return 3;
  return 4;
}

/// All sponsors at once, no sliding: a small "Disponsori" caption and a grid of
/// equal 16:9 tiles with no border or background. Short last row is centred.
/// Every sponsor is counted as viewed once, when at least half of the grid is
/// really on screen (same rule as the carousel); a tap goes through [onOpen],
/// which asks first and counts only after the person agrees.
class SponsorGrid extends StatefulWidget {
  const SponsorGrid({
    super.key,
    required this.items,
    required this.onOpen,
    this.onShown,
    this.maxWidth = 320,
    this.captionColor,
  });

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> sponsor) onOpen;
  final void Function(Map<String, dynamic> sponsor)? onShown;
  final double maxWidth;
  final Color? captionColor;

  @override
  State<SponsorGrid> createState() => _SponsorGridState();
}

class _SponsorGridState extends State<SponsorGrid> {
  static const _gap = 8.0;
  Timer? _timer;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    if (widget.onShown != null) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _reportShown(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportShown());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _inView {
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
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, seen.center, view.viewId);
    return result.path.any((e) => e.target == box);
  }

  void _reportShown() {
    if (_reported || !_inView) return;
    _reported = true;
    _timer?.cancel();
    for (final s in widget.items.take(kMaxSponsorSlides)) {
      widget.onShown?.call(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items.take(kMaxSponsorSlides).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color =
        widget.captionColor ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8);
    final cols = sponsorGridColumns(items.length);
    final count3 = items.length <= 3;
    // The translucent listener makes the whole grid answer the hit test in
    // _inView, even at a gap between two tiles.
    return Listener(
      behavior: HitTestBehavior.translucent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth.isFinite ? c.maxWidth : widget.maxWidth;
              // One or two sponsors would be huge; keep tiles to a banner size.
              final tileW = ((w - _gap * (cols - 1)) / cols).clamp(
                0.0,
                count3 ? 110.0 : 160.0,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
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
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: _gap,
                    runSpacing: _gap,
                    children: [
                      for (final s in items)
                        SizedBox(
                          width: tileW,
                          height: tileW * 9 / 16,
                          child: _Tile(item: s, onTap: () => widget.onOpen(s)),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final url = item['image_url'] as String? ?? '';
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      container: true,
      button: true,
      label: '${tr('Disponsori')}: $name',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: url.isEmpty
                ? const SizedBox.shrink()
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    memCacheWidth: (320 * dpr).round(),
                    fadeInDuration: Duration.zero,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
          ),
        ),
      ),
    );
  }
}
