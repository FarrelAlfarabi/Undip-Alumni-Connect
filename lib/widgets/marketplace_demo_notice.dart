import 'package:flutter/material.dart';

/// Unobtrusive banner shown on every marketplace screen.
class MarketplaceDemoNotice extends StatelessWidget {
  const MarketplaceDemoNotice({super.key});

  /// True once the person pressed Tutup. The card stays hidden on every
  /// marketplace screen until the app restarts.
  static final _hidden = ValueNotifier<bool>(false);

  @visibleForTesting
  static void resetForTest() => _hidden.value = false;

  static const text =
      'Produk, usaha, dan lowongan yang diunggah alumni sepenuhnya menjadi tanggung jawab alumni (bukan tanggung jawab IKAFE). Pastikan validitasnya dan laporkan jika ada hal mencurigakan.';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _hidden,
    builder: (context, hidden, _) =>
        hidden ? const SizedBox.shrink() : _card(context),
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
          content: const Text(text),
          actions: [
            TextButton(
              onPressed: () {
                _hidden.value = true;
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
                text,
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
