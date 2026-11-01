import 'package:flutter/material.dart';

/// Unobtrusive banner shown on every marketplace screen.
class MarketplaceDemoNotice extends StatelessWidget {
  const MarketplaceDemoNotice({super.key});

  static const text =
      'Produk, usaha, dan lowongan yang diunggah alumni sepenuhnya menjadi tanggung jawab alumni (bukan tanggung jawab IKAFE). Pastikan validitasnya dan laporkan jika ada hal mencurigakan.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The notice is long. It shows at most three lines so the list keeps its
    // room on small screens; a tap opens the full text.
    return InkWell(
      key: const Key('marketplace-notice'),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          content: const Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
