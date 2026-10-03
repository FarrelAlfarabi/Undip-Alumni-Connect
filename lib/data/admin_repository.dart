import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business.dart';

enum AdminErrorCode {
  notAdmin,
  invalidBand,
  reasonRequired,
  invalidState,
  invalidAction,
  notFound,
  unknown,
}

class AdminException implements Exception {
  const AdminException(this.code, this.message);
  final AdminErrorCode code;
  final String message;

  @override
  String toString() => 'AdminException(${code.name}): $message';
}

/// Plain sentence for a failed admin action. Never shows raw errors.
String adminErrorMessage(Object error) {
  if (error is AdminException) {
    switch (error.code) {
      case AdminErrorCode.notAdmin:
        return 'You are not an admin.';
      case AdminErrorCode.invalidBand:
        return 'Choose one of the four bands.';
      case AdminErrorCode.reasonRequired:
        return 'A reason is required.';
      case AdminErrorCode.invalidState:
        return 'That is not possible in the current status. Reload the list.';
      case AdminErrorCode.notFound:
        return 'This item no longer exists.';
      case AdminErrorCode.invalidAction:
      case AdminErrorCode.unknown:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}

/// Thin seam over the Supabase client (every call is a database function).
abstract class AdminApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);
}

class SupabaseAdminApi implements AdminApi {
  SupabaseAdminApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);
}

/// Admin calls. The admin id is sent with every call and checked by the
/// database against app_admins. With no real login that id is NOT
/// authenticated: accepted for the closed beta only (see docs/DECISIONS.md).
class AdminRepository {
  AdminRepository([AdminApi? api]) : _api = api ?? SupabaseAdminApi();
  final AdminApi _api;

  /// Asked once per session. Never cached on the device.
  Future<bool> isAdmin(String profileId) async {
    final r = await _guard(
      () => _api.rpc('is_app_admin', {'p_profile': profileId}),
    );
    return r == true;
  }

  /// [status] null means every business. Pending ones come first.
  Future<List<Business>> businesses(String adminId, {String? status}) async {
    final rows = await _guard(
      () => _api.rpc('admin_businesses_list', {
        'p_admin': adminId,
        'p_status': status,
      }),
    );
    return (rows as List)
        .map((r) => Business.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Business> approve(
    String adminId,
    String businessId,
    BusinessBand band,
  ) => _decide(adminId, businessId, 'approve', band: band.name);

  Future<Business> reject(String adminId, String businessId, String reason) =>
      _decide(adminId, businessId, 'reject', reason: reason);

  Future<Business> suspend(
    String adminId,
    String businessId, {
    String? reason,
  }) => _decide(adminId, businessId, 'suspend', reason: reason);

  Future<Business> restore(String adminId, String businessId) =>
      _decide(adminId, businessId, 'restore');

  Future<Business> _decide(
    String adminId,
    String businessId,
    String action, {
    String? band,
    String? reason,
  }) async {
    final row = await _guard(
      () => _api.rpc('admin_business_decide', {
        'p_admin': adminId,
        'p_business': businessId,
        'p_action': action,
        'p_band': band,
        'p_reason': reason?.trim(),
      }),
    );
    final map = row is List ? row.first : row;
    return Business.fromMap(Map<String, dynamic>.from(map as Map));
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw AdminException(_code(e.message), e.message);
    }
  }

  AdminErrorCode _code(String m) => switch (m) {
    'not_admin' => AdminErrorCode.notAdmin,
    'invalid_band' => AdminErrorCode.invalidBand,
    'reason_required' => AdminErrorCode.reasonRequired,
    'invalid_state' => AdminErrorCode.invalidState,
    'invalid_action' => AdminErrorCode.invalidAction,
    'not_found' => AdminErrorCode.notFound,
    _ => AdminErrorCode.unknown,
  };
}
