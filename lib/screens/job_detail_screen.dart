import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/application_status.dart';
import '../util/friendly_error.dart';
import 'apply_job_screen.dart';
import 'job_applicants_screen.dart';
import 'post_job_screen.dart';

/// Job detail view. Job seekers see the full posting, the poster's contact
/// info and the Apply button for free; the subscription requirement sits on
/// posting a job instead (see job_board_screen.dart).
///
/// Also the entry point for the job application feature (added 17 Sep
/// 2026): other alumni can apply (see apply_job_screen.dart); the poster sees an
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
  late Map<String, dynamic> _job = widget.job;
  Future<int>? _applicantCountFuture;
  Future<Map<String, dynamic>?>? _applicationFuture;

  bool get _isOwnJob => _job['posted_by'] == widget.currentUser.value['id'];

  @override
  void initState() {
    super.initState();
    if (_isOwnJob) {
      _applicantCountFuture = _fetchApplicantCount();
    } else {
      _applicationFuture = _fetchApplication();
    }
  }

  Future<int> _fetchApplicantCount() async {
    final rows = await Supabase.instance.client
        .from('job_applications')
        .select('id')
        .eq('job_post_id', _job['id']);
    return (rows as List).length;
  }

  // The applicant's own application for this job, if any — drives the
  // Apply button (also a UI guard against duplicates, since there's no
  // unique constraint at the database level) and shows its status.
  Future<Map<String, dynamic>?> _fetchApplication() async {
    final rows = await Supabase.instance.client
        .from('job_applications')
        .select('id, status')
        .eq('job_post_id', _job['id'])
        .eq('applicant_id', widget.currentUser.value['id'])
        .order('created_at', ascending: false)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? null : list.first;
  }

  Future<void> _apply(BuildContext context) async {
    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ApplyJobScreen(job: _job, applicant: widget.currentUser.value),
      ),
    );
    if (!mounted) return;
    // Re-read the application so the real status shows, but if the
    // apply screen reported success and the read comes back empty or
    // fails, still show it as applied rather than offering Apply again.
    final justApplied = applied == true;
    Map<String, dynamic>? fallback() =>
        justApplied ? {'status': ApplicationStatus.pending} : null;
    setState(() {
      _applicationFuture = _fetchApplication()
          .then((a) => a ?? fallback())
          .catchError((_) => fallback());
    });
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostJobScreen(
          posterId: widget.currentUser.value['id'] as String,
          existing: _job,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      final fresh = await Supabase.instance.client
          .from('job_posts')
          .select('*, poster:alumni_profiles(name)')
          .eq('id', _job['id'])
          .single();
      if (mounted) setState(() => _job = Map<String, dynamic>.from(fresh));
    } catch (_) {
      // The edit itself saved; the list refreshes when you go back.
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this job?'),
        content: const Text(
          'This also removes every application and notification for it. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('job-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Supabase.instance.client.rpc(
        'delete_job_post',
        params: {
          'p_job': _job['id'],
          'p_poster': widget.currentUser.value['id'],
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete the job. ${friendlyError(e)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poster = _job['poster'] as Map<String, dynamic>?;
    final posterName = poster?['name'] as String? ?? 'Alumni';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          if (_isOwnJob)
            PopupMenuButton<String>(
              key: const Key('job-menu'),
              onSelected: (v) => v == 'edit' ? _edit() : _delete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit job')),
                PopupMenuItem(value: 'delete', child: Text('Delete job')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _job['title'] as String? ?? '',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      _job['company'] as String? ?? '',
                      if ((_job['industry'] as String?)?.isNotEmpty == true)
                        _job['industry'] as String,
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _job['description'] as String? ?? '',
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
                        final notify = _job['notify_on_apply'] != false;
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
                                            builder: (_) =>
                                                JobApplicantsScreen(job: _job),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.mail_outline,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _job['contact_info'] as String? ??
                                      'No contact info provided.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _applicationFuture,
                          builder: (context, snapshot) {
                            final application = snapshot.data;
                            if (application != null) {
                              final status = ApplicationStatus.label(
                                application['status'] as String?,
                              );
                              return FilledButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.check_circle_outline),
                                label: Text('Applied · $status'),
                              );
                            }
                            return FilledButton.icon(
                              onPressed: () => _apply(context),
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Apply to this Job'),
                            );
                          },
                        ),
                      ],
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
