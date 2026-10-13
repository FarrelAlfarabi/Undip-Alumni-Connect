import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';

/// A business row as the SQL functions return it.
Map<String, dynamic> businessMap({
  String id = 'b1',
  String ownerId = 'me',
  String name = 'Kopi Ahmad',
  String description = 'Kopi dari Semarang',
  String category = 'Food & Drink',
  String status = 'pending',
  String? social = 'https://instagram.com/kopi_ahmad',
  String? website,
  String requestedBand = 'small',
  String? approvedBand,
  String? reason,
  String? unlimitedUntil,
  String? ownerName,
  String? reviewedAt,
  bool personal = false,
  String? photoUrl,
}) => {
  'id': id,
  'owner_id': ownerId,
  'name': name,
  'description': description,
  'category': category,
  'social_link': social,
  'website_link': website,
  'requested_band': requestedBand,
  'approved_band': approvedBand,
  'status': status,
  'rejection_reason': reason,
  'unlimited_until': unlimitedUntil,
  'created_at': '2026-10-01T08:00:00+00:00',
  'owner_name': ?ownerName,
  'reviewed_at': ?reviewedAt,
  'is_personal': personal,
  'photo_url': photoUrl,
};

class FakeBusinessApi implements BusinessApi {
  final calls = <String>[];
  final params = <String, Map<String, dynamic>>{};
  final results = <String, dynamic>{};

  /// Throw this from the next call (then cleared).
  Object? throwOnCall;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async {
    calls.add(function);
    params[function] = p;
    final t = throwOnCall;
    if (t != null) {
      throwOnCall = null;
      throw t;
    }
    return results[function] ?? <dynamic>[];
  }

  /// Paths passed to [uploadPhoto], in order.
  final uploads = <String>[];

  /// Throw this from the next upload (then cleared).
  Object? throwOnUpload;

  @override
  Future<String> uploadPhoto(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    uploads.add(path);
    final t = throwOnUpload;
    if (t != null) {
      throwOnUpload = null;
      throw t;
    }
    return 'https://files.example/storage/v1/object/public/business-photos/$path';
  }
}

PostgrestException pgError(String message) =>
    PostgrestException(message: message, code: 'P0001');
