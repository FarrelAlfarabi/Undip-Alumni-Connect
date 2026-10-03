import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/marketplace_repository.dart';
import '../data/notification_repository.dart';
import '../models/app_notification.dart';
import '../util/friendly_error.dart';
import 'admin_reports_screen.dart';
import 'admin_screen.dart';
import 'email_log_screen.dart';
import 'job_applicants_screen.dart';
import 'my_businesses_screen.dart';
import 'my_listings_screen.dart';
import 'requests_screen.dart';
import '../widgets/error_view.dart';

/// Shown when the thing a notification points at is gone or hidden.
const String kNotificationGone = 'This is no longer available.';

/// Where tapping a notification goes.
enum NotificationDestination {
  requestsReceived,
  requestsSent,
  myBusinesses,
  myListings,
  hiddenJobInfo,
  adminReports,
  adminBusinesses,
  jobApplicants,
  none,
}

NotificationDestination destinationOf(AppNotification n) {
  switch (n.type) {
    case 'contact_request_received':
      return NotificationDestination.requestsReceived;
    case 'contact_request_accepted':
      return NotificationDestination.requestsSent;
    case 'business_approved' ||
        'business_rejected' ||
        'business_suspended' ||
        'business_restored':
      return NotificationDestination.myBusinesses;
    case 'content_hidden':
      return switch (n.targetType) {
        'business' => NotificationDestination.myBusinesses,
        'product' => NotificationDestination.myListings,
        _ => NotificationDestination.hiddenJobInfo,
      };
    case 'report_new':
      return NotificationDestination.adminReports;
    case 'business_pending':
      return NotificationDestination.adminBusinesses;
    default:
      // Job applications, and old rows that only carry a job id.
      final jobId = n.type == 'job_application'
          ? (n.targetId ?? n.jobPostId)
          : n.jobPostId;
      return jobId == null
          ? NotificationDestination.none
          : NotificationDestination.jobApplicants;
  }
}

typedef NotificationPageBuilder = Widget Function(
  NotificationDestination destination,
  AppNotification notification,
  ValueNotifier<Map<String, dynamic>> currentUser,
  Map<String, dynamic>? job,
);

Widget defaultNotificationPage(
  NotificationDestination d,
  AppNotification n,
  ValueNotifier<Map<String, dynamic>> user,
  Map<String, dynamic>? job,
) {
  final me = user.value['id'] as String;
  return switch (d) {
    NotificationDestination.requestsReceived => RequestsScreen(
      currentUser: user,
    ),
    NotificationDestination.requestsSent => RequestsScreen(
      currentUser: user,
      initialTab: 1,
    ),
    NotificationDestination.myBusinesses => MyBusinessesScreen(ownerId: me),
    NotificationDestination.myListings => MyListingsScreen(
      sellerId: me,
      repository: MarketplaceRepository(),
    ),
    NotificationDestination.adminReports => AdminReportsScreen(
      adminId: me,
      repository: AdminRepository(),
    ),
    NotificationDestination.adminBusinesses => AdminBusinessesScreen(
      adminId: me,
      repository: AdminRepository(),
    ),
    NotificationDestination.jobApplicants => JobApplicantsScreen(job: job!),
    NotificationDestination.hiddenJobInfo ||
    NotificationDestination.none => const SizedBox.shrink(),
  };
}

/// In-app notifications, newest first. Rows are created only by the database
/// (triggers), never by the app. Opening the screen marks them read; the ones
/// that were new stay highlighted until you leave. Tapping one opens the
/// right screen. There is no push notification (that needs a Firebase
/// project and keys).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.currentUser,
    this.repository,
    this.buildPage = defaultNotificationPage,
  });

  /// Injectable for tests.
  final NotificationPageBuilder buildPage;

  final ValueNotifier<Map<String, dynamic>> currentUser;
  final NotificationRepository? repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationRepository _repo =
      widget.repository ?? NotificationRepository();
  late Future<List<AppNotification>> _future;

  String get _myId => widget.currentUser.value['id'] as String;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() async {
    final items = await _repo.list(_myId);
    // Mark as read on open. A failure here must not hide the list.
    try {
      await _repo.markAllRead(_myId);
    } catch (_) {}
    return items;
  }

  void _reload() => setState(() {
    _future = _load();
  });

  void _gone() =>
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(kNotificationGone)));

  Future<void> _open(AppNotification n) async {
    final nav = Navigator.of(context);
    final d = destinationOf(n);
    switch (d) {
      case NotificationDestination.none:
        return;
      case NotificationDestination.hiddenJobInfo:
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(n.title),
            content: Text(n.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      case NotificationDestination.jobApplicants:
        final jobId = n.type == 'job_application'
            ? (n.targetId ?? n.jobPostId)
            : n.jobPostId;
        Map<String, dynamic>? job;
        try {
          job = await _repo.job(jobId!);
        } catch (_) {
          job = null;
        }
        if (!mounted) return;
        if (job == null) {
          _gone();
          return;
        }
        nav.push(
          MaterialPageRoute(
            builder: (_) => widget.buildPage(d, n, widget.currentUser, job),
          ),
        );
      default:
        nav.push(
          MaterialPageRoute(
            builder: (_) => widget.buildPage(d, n, widget.currentUser, null),
          ),
        );
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _icon(AppNotification n) => switch (n.type) {
    'contact_request_received' ||
    'contact_request_accepted' => Icons.handshake_outlined,
    'business_approved' ||
    'business_rejected' ||
    'business_suspended' ||
    'business_restored' ||
    'business_pending' => Icons.business_center_outlined,
    'content_hidden' => Icons.visibility_off_outlined,
    'report_new' => Icons.flag_outlined,
    _ => Icons.work_outline,
  };

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
                builder: (_) => EmailLogScreen(
                  recipientEmail:
                      widget.currentUser.value['email'] as String? ?? '',
                ),
              ),
            ),
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Emails (simulated)',
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              message: friendlyLoadError('notifications', snap.error),
              screen: 'Notifications',
              error: snap.error,
              onRetry: _reload,
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No notifications yet. Things like new requests and '
                  'decisions on your business show up here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final fresh = n.isUnread;
              return ListTile(
                key: Key('notification-${n.id}'),
                tileColor: fresh
                    ? theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.35,
                      )
                    : null,
                leading: Icon(
                  _icon(n),
                  color: fresh
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: fresh ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                subtitle: Text(n.body),
                trailing: Text(
                  _timeAgo(n.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => _open(n),
              );
            },
          );
        },
      ),
    );
  }
}
