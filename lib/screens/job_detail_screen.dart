import 'package:flutter/material.dart';

import 'subscribe_screen.dart';

/// Job detail view + contact-poster visual paywall (Day 6, demo scope).
/// Free users see the job in full but the poster's contact info is locked
/// behind Subscribe. No real payment — see subscribe_screen.dart.
///
/// [currentUser] is a shared notifier (see profile_detail_screen.dart's
/// doc comment) so subscribing here, or from messaging, unlocks contact
/// info on every job — not just the one open when the user subscribed.
class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({
    super.key,
    required this.job,
    required this.currentUser,
  });

  final Map<String, dynamic> job;
  final ValueNotifier<Map<String, dynamic>> currentUser;

  Future<void> _unlockContact(BuildContext context) async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => SubscribeScreen(profile: currentUser.value),
      ),
    );
    if (updated != null) {
      currentUser.value = updated;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poster = job['poster'] as Map<String, dynamic>?;
    final posterName = poster?['name'] as String? ?? 'Alumni';

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    job['title'] as String? ?? '',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      job['company'] as String? ?? '',
                      if ((job['industry'] as String?)?.isNotEmpty == true)
                        job['industry'] as String,
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    job['description'] as String? ?? '',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Posted by $posterName',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ValueListenableBuilder<Map<String, dynamic>>(
                    valueListenable: currentUser,
                    builder: (context, user, _) {
                      final isSubscribed =
                          user['subscription_status'] == 'subscribed';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: isSubscribed
                                ? Row(
                                    children: [
                                      Icon(
                                        Icons.mail_outline,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          job['contact_info'] as String? ??
                                              'No contact info provided.',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Contact: locked. Subscribe to see '
                                          'how to reach the poster.',
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          if (!isSubscribed) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _unlockContact(context),
                              icon: const Icon(Icons.lock_open_outlined),
                              label: const Text('Subscribe to Contact'),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
