import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../config/policy_config.dart';
import '../util/app_info.dart';

/// Profile > About. Shows the same label that feedback reports carry.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('About'))),
      body: SafeArea(
        top: false,
        child: Padding(
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
                    tr(
                      'This is a closed beta for a small group of FEB UNDIP '
                      'alumni. Things can change or break. Use "Send feedback" '
                      'when something looks wrong.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('Who runs this app'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trf('{0}\n{1}\nEmail: {2}', [
                      kOperatorName,
                      kOperatorAddress,
                      kContactEmail,
                    ]),
                    key: const Key('about-operator'),
                    style: theme.textTheme.bodyMedium,
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
