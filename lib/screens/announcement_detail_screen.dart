import 'package:flutter/material.dart';

import '../data/marketplace_format.dart';
import '../widgets/announcement_card.dart';

/// Full text of one announcement, opened from a Home banner.
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final Map<String, dynamic> announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = DateTime.tryParse(
      announcement['created_at'] as String? ?? '',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnnouncementCard(a: announcement),
                  if (created != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Posted ${formatPostedDate(created)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
