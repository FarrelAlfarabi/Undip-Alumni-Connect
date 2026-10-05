import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../models/app_notification.dart';

/// Thin seam over the Supabase client. The app only READS notifications and
/// marks them read. It never inserts one (the database does).
abstract class NotificationApi {
  Future<List<Map<String, dynamic>>> list(String recipientId);
  Future<int> unreadCount(String recipientId);
  Future<void> markAllRead(String recipientId);

  /// The job, or null when it is gone or hidden.
  Future<Map<String, dynamic>?> job(String jobId);
}

class SupabaseNotificationApi implements NotificationApi {
  SupabaseNotificationApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> list(String recipientId) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', recipientId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Future<int> unreadCount(String recipientId) async {
    final rows = await _client
        .from('notifications')
        .select('id, type, target_type')
        .eq('recipient_id', recipientId)
        .filter('read_at', 'is', null);
    return (rows as List)
        .map(
          (r) => AppNotification.fromMap({
            'id': r['id'],
            'created_at': null,
            'type': r['type'],
            'target_type': r['target_type'],
          }),
        )
        .where((n) => chatEnabled || !n.isChat)
        .length;
  }

  @override
  Future<void> markAllRead(String recipientId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_id', recipientId)
        .filter('read_at', 'is', null);
  }

  @override
  Future<Map<String, dynamic>?> job(String jobId) async {
    final row = await _client
        .from('job_posts')
        .select()
        .eq('id', jobId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }
}

class NotificationRepository {
  NotificationRepository([NotificationApi? api])
    : _api = api ?? SupabaseNotificationApi();
  final NotificationApi _api;

  /// Newest first. Anything that links to chat is left out while chat is off.
  Future<List<AppNotification>> list(
    String recipientId, {
    bool chat = chatEnabled,
  }) async {
    final rows = await _api.list(recipientId);
    final all = rows.map(AppNotification.fromMap).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return chat ? all : all.where((n) => !n.isChat).toList();
  }

  Future<int> unreadCount(String recipientId) => _api.unreadCount(recipientId);

  Future<void> markAllRead(String recipientId) => _api.markAllRead(recipientId);

  Future<Map<String, dynamic>?> job(String jobId) => _api.job(jobId);
}
