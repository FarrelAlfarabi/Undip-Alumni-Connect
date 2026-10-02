import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'email_log_screen.dart';
import 'job_applicants_screen.dart';
import 'job_detail_screen.dart';
import '../widgets/load_error_view.dart';

/// In-app notification list (added 18 Sep 2026). A row here is created
/// automatically by a database trigger whenever someone applies to a
/// job the current user posted (see notify_poster_on_application in
/// 20260918100000_add_notifications.sql) — not written by the app, so it
/// can't be skipped by a client bug. Tapping a notification marks it
/// read and opens that job's applicant list.
///
/// The same trigger also logs the email that would be sent (real
/// sending needs a transactional provider this demo doesn't have yet)
/// — see the mail icon in the AppBar, which opens email_log_screen.dart.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserEmail,
    required this.currentUser,
  });

  final String currentUserId;
  final String currentUserEmail;

  /// Needed to open a job's detail page from an application-status update.
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchNotifications();
  }

  Future<List<Map<String, dynamic>>> _fetchNotifications() async {
    final rows = await Supabase.instance.client
        .from('notifications')
        .select()
        .eq('recipient_id', widget.currentUserId)
        .order('created_at', ascending: false);
    final notifications = List<Map<String, dynamic>>.from(rows as List);
    // Opening the list counts as seeing them: clear the unread badge on
    // the Job Board. This screen still shows them highlighted this once,
    // since `notifications` was read before the update.
    if (notifications.any((n) => n['read_at'] == null)) {
      await _markAllRead();
    }
    return notifications;
  }

  Future<void> _markAllRead() async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', widget.currentUserId)
          .filter('read_at', 'is', null);
    } catch (_) {
      // Best effort: the list is still shown if marking read fails.
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final jobPostId = notification['job_post_id'] as String?;
    if (jobPostId == null || !mounted) return;

    final job = await Supabase.instance.client
        .from('job_posts')
        .select('*, poster:alumni_profiles(name)')
        .eq('id', jobPostId)
        .maybeSingle();
    if (job == null || !mounted) return;

    // "Someone applied" goes to the poster's applicant list; "your
    // application changed" goes to the applicant, on the job itself.
    final isPoster = job['posted_by'] == widget.currentUserId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isPoster
            ? JobApplicantsScreen(job: job)
            : JobDetailScreen(job: job, currentUser: widget.currentUser),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    EmailLogScreen(recipientEmail: widget.currentUserEmail),
              ),
            ),
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Emails (simulated)',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return LoadErrorView(
              thing: 'notifications',
              error: snapshot.error,
              onRetry: () => setState(() => _future = _fetchNotifications()),
            );
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No notifications yet.'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _fetchNotifications());
              await _future;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = notifications[i];
                final isUnread = n['read_at'] == null;
                final createdAt = DateTime.parse(n['created_at'] as String);

                return ListTile(
                  tileColor: isUnread
                      ? theme.colorScheme.secondaryContainer.withValues(
                          alpha: 0.35,
                        )
                      : null,
                  leading: Icon(
                    Icons.work_outline,
                    color: isUnread
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    n['title'] as String? ?? '',
                    style: TextStyle(
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(n['body'] as String? ?? ''),
                  trailing: Text(
                    _timeAgo(createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => _openNotification(n),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
