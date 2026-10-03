/// One in-app notification. Rows are created only by the database.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.type,
    this.targetType,
    this.targetId,
    this.jobPostId,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  /// For example `contact_request_received`. Null for old rows.
  final String? type;
  final String? targetType;
  final String? targetId;

  /// Old rows (job applications) link to a job this way.
  final String? jobPostId;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  /// Anything that would open chat. Hidden while chat is off.
  bool get isChat =>
      (type ?? '').startsWith('chat') ||
      targetType == 'conversation' ||
      targetType == 'chat';

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    body: m['body'] as String? ?? '',
    createdAt: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
    type: m['type'] as String?,
    targetType: m['target_type'] as String?,
    targetId: m['target_id'] as String?,
    jobPostId: m['job_post_id'] as String?,
    readAt: m['read_at'] == null ? null : DateTime.tryParse('${m['read_at']}'),
  );
}
