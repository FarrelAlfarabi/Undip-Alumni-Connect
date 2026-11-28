import 'package:flutter/material.dart';

import '../data/home_repository.dart';
import '../platform/breakpoints.dart';
import '../util/app_language.dart';
import '../util/safe_url.dart';
import 'sponsor_banner.dart';
import 'sponsor_grid.dart';

/// PREVIEW: Welcome and PIN lock show every sponsor at once as a still grid.
/// Set to false to get the sliding carousel back.
const bool kStartScreensUseGrid = true;

/// Widest the sponsor card gets on the start screens (Welcome and PIN lock),
/// so it sits neatly above the form on a phone and inside the card on a
/// wide screen.
const double kSponsorSlotMaxWidth = 320;

/// Loads the live sponsors. The database function `home_sponsors()` is open
/// to signed-out visitors, so this works before login.
typedef SponsorLoader = Future<List<Map<String, dynamic>>> Function();

typedef SponsorEventSender = Future<void> Function(String id, String kind);

Future<List<Map<String, dynamic>>> _defaultLoader() =>
    SupabaseHomeApi().currentSponsors();

Future<void> _defaultSender(String id, String kind) =>
    SupabaseHomeApi().recordSponsorEvent(id, kind);

/// The sponsor carousel for screens shown before Home (Welcome, PIN lock).
/// Shows nothing while loading, when there is no sponsor, or when anything
/// fails (no Supabase, no internet), so these screens never wait on it.
/// Counts a view once per sponsor while the card is really visible and a tap
/// only after the person agrees to leave the app (same rules as Home).
class SponsorSlot extends StatefulWidget {
  const SponsorSlot({
    super.key,
    this.loader,
    this.sender,
    this.openLink,
    this.maxWidth = kSponsorSlotMaxWidth,
    this.autoAdvance = const Duration(seconds: 5),
    this.dark = false,
  });

  final SponsorLoader? loader;
  final SponsorEventSender? sender;
  final Future<bool> Function(String? url)? openLink;
  final double maxWidth;
  final Duration autoAdvance;

  /// On the black PIN lock screen: light caption.
  final bool dark;

  @override
  State<SponsorSlot> createState() => _SponsorSlotState();
}

class _SponsorSlotState extends State<SponsorSlot> {
  List<Map<String, dynamic>> _items = const [];
  final _counted = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await (widget.loader ?? _defaultLoader)();
      if (mounted) setState(() => _items = rows);
    } catch (_) {
      // No sponsors is fine.
    }
  }

  void _send(String id, String kind) {
    try {
      (widget.sender ?? _defaultSender)(id, kind).catchError((_) {});
    } catch (_) {}
  }

  void _shown(Map<String, dynamic> s) {
    final id = s['id'] as String?;
    if (id == null || !_counted.add(id)) return;
    _send(id, 'view');
  }

  Future<void> _open(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Buka tautan sponsor ini?')),
        content: Text(
          tr('Kamu akan meninggalkan Lingkaran dan membuka situs sponsor.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(tr('Buka')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = s['id'] as String?;
    if (id != null) _send(id, 'tap');
    await (widget.openLink ?? openHttpUrl)(s['link_url'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    if (kStartScreensUseGrid) {
      return SponsorGrid(
        items: _items,
        onOpen: _open,
        onShown: _shown,
        maxWidth: widget.maxWidth,
        captionColor: widget.dark ? const Color(0xB3FFFFFF) : null,
      );
    }
    return SponsorBanner(
      items: _items,
      onOpen: _open,
      onShown: _shown,
      autoAdvance: widget.autoAdvance,
      maxWidth: widget.maxWidth,
      seamless: true,
      captionColor: widget.dark ? const Color(0xB3FFFFFF) : null,
    );
  }
}

/// A start screen with the sponsor carousel pinned to the bottom of a phone
/// screen, under the content and above the safe area. The content scrolls on
/// its own, so the carousel never covers a button or the PIN pad. On tablet
/// and desktop the carousel sits inside the centred card instead (see
/// [SponsorInCard]), so it is not left alone on a wide empty strip.
class SponsorFooterFrame extends StatelessWidget {
  const SponsorFooterFrame({
    super.key,
    required this.child,
    this.loader,
    this.dark = false,
  });

  final Widget child;
  final SponsorLoader? loader;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (stepForWidth(constraints.maxWidth) != ScreenStep.phone) {
          return child;
        }
        return Column(
          children: [
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: child,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: SponsorSlot(
                  key: const Key('start-sponsors'),
                  loader: loader,
                  dark: dark,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The carousel at the bottom of the card on tablet and desktop. Nothing on a
/// phone (there [SponsorFooterFrame] pins it to the screen bottom).
class SponsorInCard extends StatelessWidget {
  const SponsorInCard({super.key, this.loader, this.dark = false});

  final SponsorLoader? loader;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final wide =
        stepForWidth(MediaQuery.sizeOf(context).width) != ScreenStep.phone;
    if (!wide) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: SponsorSlot(
        key: const Key('card-sponsors'),
        loader: loader,
        dark: dark,
      ),
    );
  }
}
