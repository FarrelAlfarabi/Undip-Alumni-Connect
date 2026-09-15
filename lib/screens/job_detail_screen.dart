import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'apply_job_screen.dart';
import 'job_applicants_screen.dart';
import 'subscribe_screen.dart';

/// Job detail view + contact-poster visual paywall (Day 6, demo scope).
/// Free users see the job in full but the poster's contact info is locked
/// behind Subscribe. No real payment — see subscribe_screen.dart.
///
/// Also the entry point for the job application feature (added 17 Sep
/// 2026): other alumni can apply (see apply_job_screen.dart), gated
/// behind subscription same as contact info; the poster sees an
/// applicant count and a link to review them (job_applicants_screen.dart)
/// instead. There's no real push/email notification in this demo — the
/// count shown here *is* the "notification," visible next time the
/// poster opens the app.
///
/// [currentUser] is a shared notifier (see profile_detail_screen.dart's
/// doc comment) so subscribing here, or from messaging, unlocks contact
/// info on every job — not just the one open when the user subscribed.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({
    super.key,
    required this.job,
    required this.currentUser,
  });

  final Map<String, dynamic> job;
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Future<int>? _applicantCountFuture;

  bool get _isOwnJob =>
      widget.job['posted_by'] == widget.currentUser.value['id'];

  @override
  void initState() {
    super.initState();
    if (_isOwnJob) {
      _applicantCountFuture = _fetchApplicantCount();
    }
  }

  Future<int> _fetchApplicantCount() async {
    final rows = await Supabase.instance.client
        .from('job_applications')
        .select('id')
        .eq('job_post_id', widget.job['id']);
    return (rows as List).length;
  }

  Future<void> _unlockContact(BuildContext context) async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => SubscribeScreen(profile: widget.currentUser.value),
      ),
    );
    if (updated != null) {
      widget.currentUser.value = updated;
    }
  }

  Future<void> _apply(BuildContext context) async {
    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ApplyJobScreen(
          job: widget.job,
          applicant: widget.currentUser.value,
        ),
      ),
    );
    if (applied == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application submitted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poster = widget.job['poster'] as Map<String, dynamic>?;
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
                    widget.job['title'] as String? ?? '',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      widget.job['company'] as String? ?? '',
                      if ((widget.job['industry'] as String?)?.isNotEmpty ==
                          true)
                        widget.job['industry'] as String,
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.job['description'] as String? ?? '',
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
                  if (_isOwnJob)
                    FutureBuilder<int>(
                      future: _applicantCountFuture,
                      builder: (context, snapshot) {
                        final count = snapshot.data;
                        final notify = widget.job['notify_on_apply'] != false;
                        // notify_on_apply on: proactive "N applications
                        // received" banner (the demo's notification
                        // surface). Off: same "View Applicants" access,
                        // without the notification-style emphasis — the
                        // poster opted out of being told.
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: notify
                                ? theme.colorScheme.secondaryContainer
                                : theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: notify
                                    ? theme.colorScheme.onSecondaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  !notify
                                      ? 'Applicant notifications are off for this job.'
                                      : count == null
                                      ? 'Loading applicants…'
                                      : count == 0
                                      ? 'No applications yet.'
                                      : '$count application${count == 1 ? '' : 's'} received.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: notify
                                        ? theme.colorScheme.onSecondaryContainer
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: count == null
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => JobApplicantsScreen(
                                              job: widget.job,
                                            ),
                                          ),
                                        );
                                      },
                                child: const Text('View Applicants'),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    ValueListenableBuilder<Map<String, dynamic>>(
                      valueListenable: widget.currentUser,
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
                                            widget.job['contact_info']
                                                    as String? ??
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
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Contact: locked. Subscribe to '
                                            'see how to reach the poster.',
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 16),
                            if (!isSubscribed)
                              FilledButton.icon(
                                onPressed: () => _unlockContact(context),
                                icon: const Icon(Icons.lock_open_outlined),
                                label: const Text('Subscribe to Contact'),
                              )
                            else
                              FilledButton.icon(
                                onPressed: () => _apply(context),
                                icon: const Icon(Icons.send_outlined),
                                label: const Text('Apply to this Job'),
                              ),
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
