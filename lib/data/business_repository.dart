import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business.dart';

/// Error codes raised by the business SQL functions (see
/// supabase/migrations/20261003100000_business_directory.sql).
enum BusinessErrorCode {
  notVerified,
  linkRequired,
  invalidLink,
  linkInUse,
  invalidInput,
  invalidCategory,
  invalidBand,
  notFound,
  notOwner,
  locked,
  unknown,
}

class BusinessException implements Exception {
  const BusinessException(this.code, this.message);

  final BusinessErrorCode code;
  final String message;

  @override
  String toString() => 'BusinessException(${code.name}): $message';
}

/// Plain sentence for a failed business action. Never shows raw errors.
String businessErrorMessage(Object error) {
  if (error is BusinessException) {
    switch (error.code) {
      case BusinessErrorCode.notVerified:
        return 'Only verified alumni can use the business directory.';
      case BusinessErrorCode.linkRequired:
        return 'Add an Instagram or social link, a website link, or both.';
      case BusinessErrorCode.invalidLink:
        return 'One of the links is not valid. Use a full link that starts '
            'with http:// or https://.';
      case BusinessErrorCode.linkInUse:
        return 'Another business already uses one of these links.';
      case BusinessErrorCode.invalidInput:
        return 'Check the name (2 to 100 characters) and the description '
            '(up to 500 characters).';
      case BusinessErrorCode.invalidCategory:
        return 'Choose a category.';
      case BusinessErrorCode.invalidBand:
        return 'Choose the yearly sales band.';
      case BusinessErrorCode.notFound:
        return 'This business no longer exists.';
      case BusinessErrorCode.notOwner:
        return 'You can only change your own business.';
      case BusinessErrorCode.locked:
        return 'This business can no longer be edited here. Please contact '
            'an admin.';
      case BusinessErrorCode.unknown:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}

/// Thin seam over the Supabase client, so the repository can be tested with a
/// fake. Every business call is a Postgres function (no direct table access).
abstract class BusinessApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);
}

class SupabaseBusinessApi implements BusinessApi {
  SupabaseBusinessApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);
}

class BusinessRepository {
  BusinessRepository([BusinessApi? api]) : _api = api ?? SupabaseBusinessApi();

  final BusinessApi _api;

  /// Registers a business. It starts as `pending`.
  Future<Business> register(String ownerId, BusinessInput input) async {
    final row = await _guard(
      () => _api.rpc('business_register', {
        'p_owner': ownerId,
        'p_name': input.name,
        'p_description': input.description,
        'p_category': input.category,
        'p_social_link': input.socialLink,
        'p_website_link': input.websiteLink,
        'p_band': input.band?.name,
      }),
    );
    return Business.fromMap(_single(row));
  }

  /// Edits a pending or rejected business. A rejected one goes back to
  /// review. The band cannot be changed.
  Future<Business> update(
    String ownerId,
    String businessId,
    BusinessInput input,
  ) async {
    final row = await _guard(
      () => _api.rpc('business_update', {
        'p_owner': ownerId,
        'p_business': businessId,
        'p_name': input.name,
        'p_description': input.description,
        'p_category': input.category,
        'p_social_link': input.socialLink,
        'p_website_link': input.websiteLink,
      }),
    );
    return Business.fromMap(_single(row));
  }

  /// The owner's own businesses, in every status.
  Future<List<Business>> mine(String ownerId) async {
    final rows = await _guard(
      () => _api.rpc('business_my', {'p_owner': ownerId}),
    );
    return _list(rows);
  }

  /// For each of the owner's businesses: free limit, products used, whether
  /// unlimited posting is on, and whether a new product is allowed.
  Future<List<BusinessUsage>> usage(String ownerId) async {
    final rows = await _guard(
      () => _api.rpc('business_my_usage', {'p_owner': ownerId}),
    );
    return (rows as List)
        .map((r) => BusinessUsage.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Approved businesses, for verified alumni.
  Future<List<Business>> directory(String viewerId) async {
    final rows = await _guard(
      () => _api.rpc('business_directory', {'p_viewer': viewerId}),
    );
    return _list(rows);
  }

  List<Business> _list(dynamic rows) => (rows as List)
      .map((r) => Business.fromMap(Map<String, dynamic>.from(r as Map)))
      .toList();

  Map<String, dynamic> _single(dynamic row) {
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

  BusinessException _translate(PostgrestException e) {
    final code = switch (e.message) {
      'not_verified' => BusinessErrorCode.notVerified,
      'link_required' => BusinessErrorCode.linkRequired,
      'invalid_link' => BusinessErrorCode.invalidLink,
      'link_in_use' => BusinessErrorCode.linkInUse,
      'invalid_input' => BusinessErrorCode.invalidInput,
      'invalid_category' => BusinessErrorCode.invalidCategory,
      'invalid_band' => BusinessErrorCode.invalidBand,
      'not_found' => BusinessErrorCode.notFound,
      'not_owner' => BusinessErrorCode.notOwner,
      'locked' => BusinessErrorCode.locked,
      _ => BusinessErrorCode.unknown,
    };
    return BusinessException(code, e.message);
  }
}
