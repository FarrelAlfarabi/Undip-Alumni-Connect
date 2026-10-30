import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../lock/lock_service.dart';

class _IntroPage {
  const _IntroPage(this.icon, this.title, this.lead, this.points);

  final IconData icon;
  final String title;
  final String lead;
  final List<String> points;
}

const _pages = [
  _IntroPage(
    Icons.people_outline,
    'Cari alumni',
    'Temukan sesama alumni yang telah terdaftar',
    [
      'Cari alumni di Tab Members.',
      'Kirim permintaan kontak.',
      'Respon akan diterima pada Fitur Request.',
    ],
  ),
  _IntroPage(
    Icons.storefront_outlined,
    'Marketplace dan Business',
    'Wadah bagi alumni mempromosikan usaha dan produknya',
    [
      'Daftarkan usahamu dulu.',
      'Produk bisa dipasang setelah usaha disetujui.',
      'Cari produk dan usaha di tab Explore.',
    ],
  ),
  _IntroPage(
    Icons.work_outline,
    'Jobs',
    'Tempat alumni memasang dan mencari lowongan kerja.',
    [
      'Pasang lowongan dari perusahaanmu.',
      'Lamar lowongan dari sesama alumni.',
      'Buka tab Explore, pilih Jobs.',
    ],
  ),
];

/// A short, skippable tour of Members, Marketplace, Business and Jobs. Shown once after
/// sign-in and reachable again from Settings.
class FeatureIntroScreen extends StatefulWidget {
  const FeatureIntroScreen({super.key, required this.onDone});

  /// Called after the last page or Skip. The caller decides what comes next
  /// (open the app, or just go back).
  final Future<void> Function(BuildContext context) onDone;

  @override
  State<FeatureIntroScreen> createState() => _FeatureIntroScreenState();
}

class _FeatureIntroScreenState extends State<FeatureIntroScreen> {
  int _index = 0;
  bool _finishing = false;

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await widget.onDone(context);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _pages[_index];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('intro-skip'),
                  onPressed: _finish,
                  child: const Text('Lewati'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        page.icon,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(page.title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(page.lead, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      for (final p in page.points)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2, right: 8),
                                child: Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  p,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('intro-next'),
                  onPressed: _next,
                  child: Text(_isLast ? 'Mulai' : 'Lanjut'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps the signed-in app. The first time a person opens it, the intro is
/// pushed on top. "Seen" lives on their profile in Supabase (asked through
/// `account_intro_seen`), so it holds across devices. The old local flag still
/// counts: a device that has it skips the intro and saves it to Supabase. When
/// Supabase cannot answer (offline, migration not applied yet) the local flag
/// decides, so the app never blocks on it.
class IntroGate extends StatefulWidget {
  const IntroGate({
    super.key,
    required this.profile,
    required this.child,
    this.lock,
    this.repository,
  });

  final Map<String, dynamic> profile;
  final Widget child;

  /// Defaults to the real device lock.
  final LockService? lock;

  /// Defaults to the real Supabase-backed repository.
  final AccountRepository? repository;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  @override
  void initState() {
    super.initState();
    _maybeShow();
  }

  Future<void> _maybeShow() async {
    final id = widget.profile['id'] as String?;
    if (id == null) return;
    final lock = widget.lock ?? LockService.shared;
    final repo = widget.repository ?? AccountRepository();

    // Best effort: a failed save only means it is tried again next time.
    Future<void> save() async {
      try {
        await repo.markIntroSeen(id);
      } catch (_) {}
    }

    bool seenHere;
    try {
      seenHere = await lock.introSeen(id);
    } catch (_) {
      seenHere = false;
    }
    if (seenHere) {
      await save();
      return;
    }
    try {
      if (await repo.introSeen(id)) {
        try {
          await lock.markIntroSeen(id);
        } catch (_) {}
        return;
      }
    } catch (_) {
      // Unknown on the server: the local flag (false here) decides.
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FeatureIntroScreen(
          onDone: (ctx) async {
            try {
              await lock.markIntroSeen(id);
            } catch (_) {}
            await save();
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
