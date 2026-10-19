import 'package:supabase_flutter/supabase_flutter.dart';

/// A WhatsApp group invite link, the same shape the database accepts.
final RegExp _inviteUrl = RegExp(
  r'^https://chat\.whatsapp\.com/[A-Za-z0-9]{10,40}$',
);

bool isWhatsAppInviteUrl(String value) => _inviteUrl.hasMatch(value.trim());

enum CityGroupErrorCode { notVerified, invalidInput, unknown }

class CityGroupException implements Exception {
  const CityGroupException(this.code);
  final CityGroupErrorCode code;

  @override
  String toString() => 'CityGroupException(${code.name})';
}

/// Plain sentence for a failed save. Never shows raw errors.
String cityGroupErrorMessage(Object error) {
  if (error is CityGroupException) {
    switch (error.code) {
      case CityGroupErrorCode.notVerified:
        return 'Hanya alumni terverifikasi yang bisa mengubah link grup.';
      case CityGroupErrorCode.invalidInput:
        return 'Link tidak valid. Gunakan link undangan grup WhatsApp, '
            'contoh: https://chat.whatsapp.com/AbCdEfGhIjKl';
      case CityGroupErrorCode.unknown:
        break;
    }
  }
  return 'Link grup belum bisa disimpan. Coba lagi sebentar lagi.';
}

abstract class CityGroupApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);
}

class SupabaseCityGroupApi implements CityGroupApi {
  SupabaseCityGroupApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);
}

/// One WhatsApp invite link per city (see 20261019110000_city_whatsapp_groups).
class CityGroupRepository {
  CityGroupRepository([CityGroupApi? api]) : _api = api;
  CityGroupApi? _api;

  CityGroupApi get _client => _api ??= SupabaseCityGroupApi();

  /// City name to invite link.
  Future<Map<String, String>> list(String viewerId) async {
    final rows = await _client.rpc('city_whatsapp_groups_list', {
      'p_viewer': viewerId,
    });
    return {
      for (final r in List<Map<String, dynamic>>.from(rows as List))
        r['city'] as String: r['invite_url'] as String,
    };
  }

  Future<void> save(String profileId, String city, String url) async {
    try {
      await _client.rpc('city_whatsapp_group_set', {
        'p_profile': profileId,
        'p_city': city,
        'p_url': url.trim(),
      });
    } catch (e) {
      final text = e.toString();
      if (text.contains('invalid_input')) {
        throw const CityGroupException(CityGroupErrorCode.invalidInput);
      }
      if (text.contains('not_verified')) {
        throw const CityGroupException(CityGroupErrorCode.notVerified);
      }
      throw const CityGroupException(CityGroupErrorCode.unknown);
    }
  }
}
