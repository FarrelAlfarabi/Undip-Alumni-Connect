import 'package:flutter/material.dart';

import '../lock/lock_store.dart';

/// Unobtrusive banner shown on every marketplace screen.
class MarketplaceDemoNotice extends StatefulWidget {
  const MarketplaceDemoNotice({super.key});

  static const _storeKey = 'marketplace_notice_dismissed';

  /// Device storage. It is not touched by sign out or "Switch account", so
  /// Tutup stays permanent on this device.
  static LockStore _store = const SecureLockStore();

  /// null = not read yet (card shows), true = dismissed. Call [preload] at
  /// app start so the saved answer is known before the first marketplace
  /// screen is built.
  static final _hidden = ValueNotifier<bool?>(null);
  static Future<void>? _loading;

  @visibleForTesting
  static void resetForTest([LockStore? store]) {
    _store = store ?? const SecureLockStore();
    _hidden.value = null;
    _loading = null;
  }

  static Future<void> preload() => _load();

  static Future<void> _load() => _loading ??= () async {
    try {
      _hidden.value = await _store.read(_storeKey) != null;
    } catch (_) {
      _hidden.value = false; // cannot read: show the card
    }
  }();

  static Future<void> _dismiss() async {
    _hidden.value = true;
    try {
      await _store.write(_storeKey, '1');
    } catch (_) {
      // Still hidden for this run; it may show again next launch.
    }
  }

  static const text =
      'Produk, usaha, dan lowongan yang diunggah alumni sepenuhnya menjadi tanggung jawab alumni (bukan tanggung jawab IKAFE). Pastikan validitasnya dan laporkan jika ada hal mencurigakan.';

  @override
  State<MarketplaceDemoNotice> createState() => _MarketplaceDemoNoticeState();
}

class _MarketplaceDemoNoticeState extends State<MarketplaceDemoNotice> {
  @override
  void initState() {
    super.initState();
    MarketplaceDemoNotice._load();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool?>(
    valueListenable: MarketplaceDemoNotice._hidden,
    builder: (context, hidden, _) =>
        hidden == true ? const SizedBox.shrink() : _card(context),
  );

  Widget _card(BuildContext context) {
    final theme = Theme.of(context);
    // The notice is long. It shows at most three lines so the list keeps its
    // room on small screens; a tap opens the full text.
    return InkWell(
      key: const Key('marketplace-notice'),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: const Text(MarketplaceDemoNotice.text),
          actions: [
            TextButton(
              onPressed: () {
                MarketplaceDemoNotice._dismiss();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
      child: Container(
        width: double.infinity,
        color: theme.colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                MarketplaceDemoNotice.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
