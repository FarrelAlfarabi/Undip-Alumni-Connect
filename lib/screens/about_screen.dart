import 'package:flutter/material.dart';

import '../config/policy_config.dart';
import '../util/app_info.dart';

/// Profile > About. Shows the same label that feedback reports carry.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<AppInfo>(
          future: AppInfo.load(),
          builder: (context, snap) {
            final info = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info?.fullLabel ?? 'Lingkaran BETA',
                  key: const Key('about-version'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'This is a closed beta for a small group of FEB UNDIP '
                  'alumni. Things can change or break. Use "Send feedback" '
                  'when something looks wrong.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Text('Who runs this app', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '$kOperatorName\n$kOperatorAddress\nEmail: $kContactEmail',
                  key: const Key('about-operator'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
