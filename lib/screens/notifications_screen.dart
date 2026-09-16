import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'job_applicants_screen.dart';

/// In-app notification list (added 18 Sep 2026). A row here is created
/// automatically by a database trigger whenever someone applies to a
/// job the current user posted (see notify_poster_on_application in
/// 20260918100000_add_notifications.sql) — not written by the app, so it
/// can't be skipped by a client bug. Tapping a notification marks it
/// read and opens that job's applicant list.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.currentUserId});

  final String currentUserId;

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
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    if (notification['read_at'] == null) {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notification['id']);
      if (mounted) setState(() => _future = _fetchNotifications());
    }

    final jobPostId = notification['job_post_id'] as String?;
    if (jobPostId == null || !mounted) return;

    final job = await Supabase.instance.client
        .from('job_posts')
        .select()
        .eq('id', jobPostId)
        .maybeSingle();
    if (job == null || !mounted) return;

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => JobApplicantsScreen(job: job)));
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
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load notifications: ${snapshot.error}'),
              ),
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

          return ListView.separated(
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
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
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
          );
        },
      ),
    );
  }
}
