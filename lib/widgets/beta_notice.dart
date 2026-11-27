import 'package:flutter/material.dart';

import '../util/app_language.dart';

/// Light beta note, shown on the consent screen: the app is a beta, it may
/// have bugs, and feedback goes through "Kirim masukan".
class BetaNotice extends StatelessWidget {
  const BetaNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('beta-notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(
                'Lingkaran masih versi beta dan mungkin masih ada bug. Kalau ada '
                'yang terlihat salah, kirim masukan lewat tombol "Kirim masukan".',
              ),
              key: const Key('beta-text'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
