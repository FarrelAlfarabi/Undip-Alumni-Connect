import 'package:flutter/material.dart';

/// Shown on Welcome and on the consent screen. This is a closed test: the
/// database cannot yet keep other people with the app key away from what
/// testers type in, so testers are asked to use test details only.
class ClosedTestNotice extends StatelessWidget {
  const ClosedTestNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('closed-test-notice'),
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
              'This is a closed test. Please use test contact details. Do not '
              'upload a real CV or enter a real phone number yet. '
              '(Ini uji coba tertutup. Gunakan data kontak percobaan, jangan '
              'unggah CV asli atau isi nomor telepon asli.)',
              key: const Key('closed-test-text'),
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
