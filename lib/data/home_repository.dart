import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business.dart';
import '../models/marketplace_listing.dart';
import 'block_list.dart';
import 'business_repository.dart';
import 'marketplace_repository.dart';
import 'notification_repository.dart';

/// How many banners the Home carousel shows at most.
const int kHomeBannerLimit = 5;

/// How many items each "Latest" strip shows.
const int kHomeLatestLimit = 3;

/// How many products and jobs Home shows. Items an admin pinned (Admin >
/// Home order) come first, the newest fill the rest.
const int kHomeListingLimit = 10;
const int kHomeJobLimit = 3;

/// How many newest listings Home asks the server for. More than
/// [kHomeListingLimit] because listings from people I blocked are dropped
/// after the fetch, and Home should still fill its strip.
const int kHomeListingFetchLimit = 30;

/// Thin seam over the Supabase client for the Home hub, so the screen can
/// be tested with a fake (same approach as MarketplaceApi).
abstract class HomeApi {
  /// Newest announcements first (same table the News screen reads).
  Future<List<Map<String, dynamic>>> latestAnnouncements(int limit);

  /// Newest job posts first, with the poster joined (same query shape as
  /// the Job Board, so the rows open in JobDetailScreen unchanged).
  ///
  /// With [pinnedOnly], only jobs an admin pinned (home_rank set), by rank.
  Future<List<Map<String, dynamic>>> latestJobs(
    int limit, {
    bool pinnedOnly = false,
  });

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
  Future<List<Map<String, dynamic>>> latestJobs(
    int limit, {
    bool pinnedOnly = false,
  }) async {
    final query = _client
        .from('job_posts')
        .select('*, poster:alumni_profiles(name)');
    final rows = await (pinnedOnly
        ? query.not('home_rank', 'is', null).order('home_rank').limit(limit)
        : query.order('created_at', ascending: false).limit(limit));
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

/// Pinned items first (by rank), then the rest, no repeats, cut to [limit].
/// [rest] must already be newest first.
List<T> mergePinned<T>({
  required List<T> pinned,
  required List<T> rest,
  required int limit,
  required String Function(T) id,
  required int? Function(T) rank,
}) {
  final first = [...pinned]..sort((a, b) => (rank(a) ?? 99) - (rank(b) ?? 99));
  final seen = {for (final p in first) id(p)};
  return [
    ...first,
    ...rest.where((r) => !seen.contains(id(r))),
  ].take(limit).toList();
}

/// The products Home shows: approved, visible and not from someone I blocked.
/// Pinned ones are fetched on their own so one older than the newest
/// [kHomeListingFetchLimit] is still found. A pinned item that is hidden,
/// rejected or sold is dropped and does not use a slot.
Future<List<MarketplaceListing>> homeListings(
  MarketplaceRepository market,
) async {
  final results = await Future.wait([
    market.fetchPinnedApproved(),
    market.fetchApproved(limit: kHomeListingFetchLimit),
  ]);
  final pinned = results[0];
  final newest = results[1];
  bool shown(MarketplaceListing l) =>
      l.status == ListingStatus.approved && !l.isHidden;
  final byDate = newest.where(shown).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return mergePinned(
    pinned: pinned.where(shown).toList(),
    rest: byDate,
    limit: kHomeListingLimit,
    id: (l) => l.id,
    rank: (l) => l.homeRank,
  );
}

/// The jobs Home shows: pinned first, then the newest. Hidden jobs and jobs
/// from blocked posters are dropped before the cut, so they use no slot.
Future<List<Map<String, dynamic>>> homeJobs(
  HomeApi api, {
  bool Function(String? posterId)? isBlocked,
}) async {
  // 99 is the most pins an admin can set, so no pin is cut before the filter.
  final results = await Future.wait([
    api.latestJobs(99, pinnedOnly: true),
    api.latestJobs(kHomeJobLimit * 10),
  ]);
  final pinned = results[0];
  final newest = results[1];
  if (isBlocked == null) await BlockList.shared.ensureLoaded();
  bool blocked(Map<String, dynamic> j) => isBlocked != null
      ? isBlocked(j['posted_by'] as String?)
      : BlockList.shared.filter([j], (r) => r['posted_by'] as String?).isEmpty;
  bool shown(Map<String, dynamic> j) => j['hidden_at'] == null && !blocked(j);
  return mergePinned(
    pinned: pinned.where(shown).toList(),
    rest: newest.where(shown).toList(),
    limit: kHomeJobLimit,
    id: (j) => j['id'] as String,
    rank: (j) => (j['home_rank'] as num?)?.toInt(),
  );
}
