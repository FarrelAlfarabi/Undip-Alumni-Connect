import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_listing.dart';

/// Error codes raised by the marketplace SQL functions (see
/// supabase/migrations/20260930090200_marketplace_functions.sql).
enum MarketplaceErrorCode {
  postingClosed,
  notFound,
  notOwner,
  notAdmin,
  invalidState,
  invalidDecision,
  reasonRequired,
  duplicateReport,
  unknown,
}

class MarketplaceException implements Exception {
  const MarketplaceException(this.code, this.message);

  final MarketplaceErrorCode code;
  final String message;

  @override
  String toString() => 'MarketplaceException(${code.name}): $message';
}

/// Thin seam over the Supabase client so the repository can be tested with
/// a fake (the project has no mocking package and we do not add one).
abstract class MarketplaceApi {
  /// Approved listings joined with their seller.
  Future<List<Map<String, dynamic>>> selectApprovedListings();

  /// Calls a Postgres function. Returns the decoded JSON result.
  Future<dynamic> rpc(String function, Map<String, dynamic> params);

  Future<void> insertReport(Map<String, dynamic> row);

  /// Full alumni_profiles row (what ProfileDetailScreen expects), or null.
  Future<Map<String, dynamic>?> selectProfile(String id);

  /// id + name for the given profile ids.
  Future<List<Map<String, dynamic>>> selectProfileNames(List<String> ids);

  /// Uploads to the `marketplace` bucket and returns the public URL.
  Future<String> uploadImage(String path, Uint8List bytes, String contentType);
}

class SupabaseMarketplaceApi implements MarketplaceApi {
  SupabaseMarketplaceApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> selectApprovedListings() async {
    final rows = await _client
        .from('marketplace_listings')
        .select(
          // Two links to alumni_profiles exist (seller_id, reviewed_by), so
          // the join names the seller one or the API rejects it as ambiguous.
          '*, seller:alumni_profiles!marketplace_listings_seller_id_fkey(id, name, faculty, major, graduation_year, city)',
        )
        .eq('status', 'approved')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) {
    return _client.rpc(function, params: params);
  }

  @override
  Future<void> insertReport(Map<String, dynamic> row) async {
    // No .select(): reports are write-only for the API (no select policy).
    await _client.from('marketplace_reports').insert(row);
  }

  @override
  Future<Map<String, dynamic>?> selectProfile(String id) async {
    final row = await _client
        .from('alumni_profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<List<Map<String, dynamic>>> selectProfileNames(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final rows = await _client
        .from('alumni_profiles')
        .select('id, name, faculty, major, graduation_year, city')
        .inFilter('id', ids);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Future<String> uploadImage(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    final bucket = _client.storage.from('marketplace');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    return bucket.getPublicUrl(path);
  }
}

/// Everything the marketplace screens need from the database.
///
/// Auth caveat: the app has no Supabase Auth session, so [sellerId] and
/// [reporterId] are plain profile ids supplied by the app. The database
/// checks them but cannot verify the caller is really that person.
class MarketplaceRepository {
  MarketplaceRepository([MarketplaceApi? api])
    : _api = api ?? SupabaseMarketplaceApi();

  final MarketplaceApi _api;

  /// Approved listings, newest first. Search/filter/sort happen client-side
  /// (same pattern as the job board).
  Future<List<MarketplaceListing>> fetchApproved() async {
    final rows = await _guard(() => _api.selectApprovedListings());
    return rows.map(MarketplaceListing.fromMap).toList();
  }

  // ---- admin (demo): see the auth caveat above; admin ids are not
  // authenticated either.

  Future<bool> isAdmin(String profileId) async {
    final result = await _guard(
      () => _api.rpc('marketplace_is_admin', {'p_profile': profileId}),
    );
    return result == true;
  }

  /// Pending listings, oldest first, with seller info attached. Needs the
  /// admin passphrase as well as the id: the id alone is public (audit SA-04).
  Future<List<MarketplaceListing>> fetchPending(
    String adminId,
    String adminKey,
  ) async {
    final rows = await _guard(
      () => _api.rpc('marketplace_admin_pending', {
        'p_admin': adminId,
        'p_key': adminKey,
      }),
    );
    final listings = _listings(rows);
    if (listings.isEmpty) return listings;
    final sellers = await _guard(
      () => _api.selectProfileNames(
        {for (final l in listings) l.sellerId}.toList(),
      ),
    );
    final byId = {
      for (final m in sellers) m['id'] as String: MarketplaceSeller.fromMap(m),
    };
    return [for (final l in listings) l.withSeller(byId[l.sellerId])];
  }

  /// Approves, or rejects with a required [reason].
  Future<MarketplaceListing> review({
    required String adminId,
    required String adminKey,
    required String listingId,
    required bool approve,
    String? reason,
  }) async {
    final row = await _guard(
      () => _api.rpc('marketplace_review_listing', {
        'p_admin': adminId,
        'p_listing': listingId,
        'p_decision': approve ? 'approved' : 'rejected',
        'p_reason': approve ? null : reason?.trim(),
        'p_key': adminKey,
      }),
    );
    return MarketplaceListing.fromMap(_single(row));
  }

  Future<List<ReportCount>> fetchReportCounts(
    String adminId,
    String adminKey,
  ) async {
    final rows = await _guard(
      () => _api.rpc('marketplace_report_counts', {
        'p_admin': adminId,
        'p_key': adminKey,
      }),
    );
    return (rows as List)
        .map((r) => ReportCount.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Uploads a listing photo and returns its public URL. The file name is
  /// sanitised and prefixed with the seller id and a timestamp.
  Future<String> uploadImage({
    required String sellerId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '$sellerId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    return _guard(
      () => _api.uploadImage(path, bytes, imageContentType(fileName)),
    );
  }

  /// The seller's full profile row, for opening their profile screen.
  Future<Map<String, dynamic>?> fetchSellerProfile(String sellerId) {
    return _guard(() => _api.selectProfile(sellerId));
  }

  /// The seller's own listings in every status.
  Future<List<MarketplaceListing>> fetchMine(String sellerId) async {
    final rows = await _guard(
      () => _api.rpc('marketplace_my_listings', {'p_seller': sellerId}),
    );
    return _listings(rows);
  }

  /// Creates a listing in `pending`. Throws
  /// [MarketplaceErrorCode.postingClosed] while posting is closed.
  Future<MarketplaceListing> create(
    String sellerId,
    MarketplaceListingInput input,
  ) async {
    final row = await _guard(
      () => _api.rpc('marketplace_create_listing', {
        'p_seller': sellerId,
        ..._inputParams(input),
      }),
    );
    return MarketplaceListing.fromMap(_single(row));
  }

  /// Saves edits. The listing goes back to `pending` whatever its state.
  Future<MarketplaceListing> update(
    String sellerId,
    String listingId,
    MarketplaceListingInput input,
  ) async {
    final row = await _guard(
      () => _api.rpc('marketplace_update_listing', {
        'p_seller': sellerId,
        'p_listing': listingId,
        ..._inputParams(input),
      }),
    );
    return MarketplaceListing.fromMap(_single(row));
  }

  Future<MarketplaceListing> markSold(String sellerId, String listingId) async {
    final row = await _guard(
      () => _api.rpc('marketplace_set_sold', {
        'p_seller': sellerId,
        'p_listing': listingId,
      }),
    );
    return MarketplaceListing.fromMap(_single(row));
  }

  Future<void> delete(String sellerId, String listingId) async {
    await _guard(
      () => _api.rpc('marketplace_delete_listing', {
        'p_seller': sellerId,
        'p_listing': listingId,
      }),
    );
  }

  /// Files a report. A second report by the same reporter on the same
  /// listing throws [MarketplaceErrorCode.duplicateReport].
  Future<void> report({
    required String listingId,
    required String reporterId,
    required ReportReason reason,
    String? note,
  }) async {
    final trimmed = note?.trim();
    await _guard(
      () => _api.insertReport({
        'listing_id': listingId,
        'reporter': reporterId,
        'reason': reason.name,
        if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
      }),
    );
  }

  Map<String, dynamic> _inputParams(MarketplaceListingInput i) => {
    'p_title': i.title,
    'p_description': i.description,
    'p_price_idr': i.priceIdr,
    'p_category': i.category,
    'p_city': i.city,
    'p_image_url': i.imageUrl,
    'p_shop_url': i.shopUrl,
    'p_contact_info': i.contactInfo,
  };

  List<MarketplaceListing> _listings(dynamic rows) {
    return (rows as List)
        .map(
          (r) =>
              MarketplaceListing.fromMap(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Map<String, dynamic> _single(dynamic row) {
    // A function returning one composite row comes back as a map.
    if (row is List && row.length == 1) row = row.first;
    return Map<String, dynamic>.from(row as Map);
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw _translate(e);
    }
  }

  MarketplaceException _translate(PostgrestException e) {
    final msg = e.message;
    if (e.code == '23505' &&
        msg.contains('marketplace_reports_one_per_reporter')) {
      return MarketplaceException(MarketplaceErrorCode.duplicateReport, msg);
    }
    final code = switch (msg) {
      'posting_closed' => MarketplaceErrorCode.postingClosed,
      'not_found' => MarketplaceErrorCode.notFound,
      'not_owner' => MarketplaceErrorCode.notOwner,
      'not_admin' => MarketplaceErrorCode.notAdmin,
      'invalid_state' => MarketplaceErrorCode.invalidState,
      'invalid_decision' => MarketplaceErrorCode.invalidDecision,
      'reason_required' => MarketplaceErrorCode.reasonRequired,
      _ => MarketplaceErrorCode.unknown,
    };
    return MarketplaceException(code, msg);
  }
}

/// Allowed listing photo extensions (matches the bucket policy).
const kListingImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

/// Bucket file size limit (2 MB).
const kListingImageMaxBytes = 2 * 1024 * 1024;

String imageContentType(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}
