import 'package:flutter/material.dart';

import 'subscribe_screen.dart';

/// Job detail view + contact-poster visual paywall (Day 6, demo scope).
/// Free users see the job in full but the poster's contact info is locked
/// behind Subscribe. No real payment — see subscribe_screen.dart.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({
    super.key,
    required this.job,
    required this.currentProfile,
  });

  final Map<String, dynamic> job;
  final Map<String, dynamic> currentProfile;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Map<String, dynamic> _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.currentProfile;
  }

  bool get _isSubscribed =>
      _currentProfile['subscription_status'] == 'subscribed';

  Future<void> _unlockContact() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => SubscribeScreen(profile: _currentProfile),
      ),
    );
    if (updated != null) {
      setState(() => _currentProfile = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = widget.job;
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isSubscribed
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
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Contact: locked. Subscribe to see how to '
                                  'reach the poster.',
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (!_isSubscribed) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _unlockContact,
                      icon: const Icon(Icons.lock_open_outlined),
                      label: const Text('Subscribe to Contact'),
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
