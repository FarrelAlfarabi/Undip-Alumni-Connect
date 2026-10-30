import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'marketplace_repository.dart' show imageContentType;

class AvatarException implements Exception {
  const AvatarException(this.message);
  final String message;

  @override
  String toString() => 'AvatarException: $message';
}

/// Thin seam over the Supabase client, so the repository can be tested with a
/// fake. See supabase/migrations/20261030170000_profile_avatar.sql.
abstract class AvatarApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);

  /// Uploads to the `avatars` bucket and returns the public URL.
  Future<String> upload(String path, Uint8List bytes, String contentType);

  /// Rows with `id` and `avatar_url` for everyone who has a photo.
  Future<dynamic> listUrls({String? id});
}

class SupabaseAvatarApi implements AvatarApi {
  SupabaseAvatarApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);

  @override
  Future<String> upload(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    final bucket = _client.storage.from('avatars');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    return bucket.getPublicUrl(path);
  }

  @override
  Future<dynamic> listUrls({String? id}) {
    final q = _client
        .from('alumni_profiles')
        .select('id, avatar_url')
        .not('avatar_url', 'is', null);
    return id == null ? q : q.eq('id', id);
  }
}

class AvatarRepository {
  AvatarRepository([AvatarApi? api]) : _api = api ?? SupabaseAvatarApi();

  final AvatarApi _api;

  /// Uploads the file and returns its public URL. The name is cleaned and
  /// prefixed with the profile id and a timestamp (a new name each time, so a
  /// changed photo is never served from a cache).
  Future<String> upload({
    required String profileId,
    required String fileName,
    required Uint8List bytes,
  }) {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '$profileId/${DateTime.now().millisecondsSinceEpoch}_$safe';
    return _guard(() => _api.upload(path, bytes, imageContentType(fileName)));
  }

  /// Saves the link on the person's own profile; null removes the photo.
  Future<String?> setAvatar(String profileId, String? url) async {
    final out = await _guard(
      () => _api.rpc('profile_set_avatar', {
        'p_profile': profileId,
        'p_url': url,
      }),
    );
    return out as String?;
  }

  /// Photo links by profile id. A failure gives none rather than an error:
  /// the lists still work with initials, for example before the migration
  /// has been applied.
  Future<Map<String, String>> urlsById({String? id}) async {
    try {
      final rows = await _api.listUrls(id: id);
      return {
        for (final r in (rows as List))
          if ((r as Map)['avatar_url'] != null)
            '${r['id']}': '${r['avatar_url']}',
      };
    } catch (_) {
      return const {};
    }
  }

  /// The same rows with `avatar_url` filled in where there is a photo.
  static List<Map<String, dynamic>> withAvatars(
    List<Map<String, dynamic>> rows,
    Map<String, String> urls,
  ) => urls.isEmpty
      ? rows
      : [
          for (final r in rows)
            urls.containsKey('${r['id']}')
                ? {...r, 'avatar_url': urls['${r['id']}']}
                : r,
        ];

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      final t = e.toString();
      if (t.contains('not_verified')) {
        throw const AvatarException(
          'Hanya alumni terverifikasi yang bisa memasang foto.',
        );
      }
      if (t.contains('invalid_input')) {
        throw const AvatarException(
          'Foto ini tidak bisa dipakai. Pilih foto lain.',
        );
      }
      throw const AvatarException('Foto belum tersimpan. Coba lagi.');
    }
  }
}
