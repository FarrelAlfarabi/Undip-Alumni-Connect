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

  // The notifications table is closed to the app. These three functions return
  // only what the screen needs (see 20261005100000_close_anon_reads.sql).
  @override
  Future<List<Map<String, dynamic>>> list(String recipientId) async {
    final rows = await _client.rpc(
      'notifications_list',
      params: {'p_recipient': recipientId},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Future<int> unreadCount(String recipientId) async {
    final count = await _client.rpc(
      'notifications_unread_count',
      params: {'p_recipient': recipientId, 'p_include_chat': chatEnabled},
    );
    return (count as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markAllRead(String recipientId) async {
    await _client.rpc(
      'notifications_mark_read',
      params: {'p_recipient': recipientId},
    );
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
