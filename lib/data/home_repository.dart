import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business.dart';
import 'business_repository.dart';
import 'notification_repository.dart';

/// How many banners the Home carousel shows at most.
const int kHomeBannerLimit = 5;

/// How many items each "Latest" strip shows.
const int kHomeLatestLimit = 3;

/// How many newest listings Home asks the server for. More than
/// [kHomeLatestLimit] because listings from people I blocked are dropped
/// after the fetch, and Home should still fill its strip.
const int kHomeListingFetchLimit = 20;

/// Thin seam over the Supabase client for the Home hub, so the screen can
/// be tested with a fake (same approach as MarketplaceApi).
abstract class HomeApi {
  /// Newest announcements first (same table the News screen reads).
  Future<List<Map<String, dynamic>>> latestAnnouncements(int limit);

  /// Newest job posts first, with the poster joined (same query shape as
  /// the Job Board, so the rows open in JobDetailScreen unchanged).
  Future<List<Map<String, dynamic>>> latestJobs(int limit);

  /// Contact requests waiting for an answer (the badge on Home).
  Future<int> pendingRequestCount(String profileId);

  /// Unread in-app notifications (the bell on Home).
  Future<int> unreadNotificationCount(String profileId);

  /// The person's own businesses, in every status (the owner card).
  Future<List<Business>> myBusinesses(String profileId);

  /// Products used out of the free limit, per business (the owner card).
  Future<List<BusinessUsage>> myBusinessUsage(String profileId);
}

class SupabaseHomeApi implements HomeApi {
  SupabaseHomeApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> latestAnnouncements(int limit) async {
    final rows = await _client
        .from('announcements')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Future<List<Map<String, dynamic>>> latestJobs(int limit) async {
    final rows = await _client
        .from('job_posts')
        .select('*, poster:alumni_profiles(name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Future<int> pendingRequestCount(String profileId) async {
    final n = await _client.rpc(
      'contact_requests_pending_count',
      params: {'p_target': profileId},
    );
    return (n as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> unreadNotificationCount(String profileId) =>
      NotificationRepository().unreadCount(profileId);

  @override
  Future<List<Business>> myBusinesses(String profileId) =>
      BusinessRepository().mine(profileId);

  @override
  Future<List<BusinessUsage>> myBusinessUsage(String profileId) =>
      BusinessRepository().usage(profileId);
}
