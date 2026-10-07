import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin seam over the Supabase client for consent and account deletion.
abstract class AccountApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);

  /// Removes files from a storage bucket. Returns the paths that were
  /// removed. May throw (for example when the app has no right to delete).
  Future<List<String>> removeFiles(String bucket, List<String> paths);
}

class SupabaseAccountApi implements AccountApi {
  SupabaseAccountApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);

  @override
  Future<List<String>> removeFiles(String bucket, List<String> paths) async {
    final removed = await _client.storage.from(bucket).remove(paths);
    return removed.map((f) => f.name).toList();
  }
}

/// What happened when an account was deleted.
class DeleteResult {
  const DeleteResult({required this.removed, required this.failedPaths});

  /// How many of each thing the database removed.
  final Map<String, int> removed;

  /// Files (bucket/path) the app could not remove. They are also in the
  /// database table storage_cleanup_queue for a manual clean-up.
  final List<String> failedPaths;
}

class AccountException implements Exception {
  const AccountException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'AccountException($code): $message';
}

class AccountRepository {
  AccountRepository([AccountApi? api]) : _api = api ?? SupabaseAccountApi();
  final AccountApi _api;

  /// Saves the accepted policy version on the profile (through a function).
  Future<void> acceptPolicy(String profileId, String version) async {
    try {
      await _api.rpc('account_accept_policy', {
        'p_profile': profileId,
        'p_version': version,
      });
    } on PostgrestException catch (e) {
      throw AccountException(e.message, e.message);
    }
  }

  /// Deletes the account: lists the person's files, calls `account_delete`
  /// (one transaction, which also queues the files in storage_cleanup_queue),
  /// and only then removes the files from storage, best effort. This order
  /// matters: if the database call fails, nothing has been destroyed yet and
  /// the person can try again.
  ///
  /// `not_found` from the database means the account is already deleted (for
  /// example the first call worked but its answer was lost), so it counts as
  /// success and the device can be wiped.
  Future<DeleteResult> deleteAccount(String profileId) async {
    final failed = <String>[];
    try {
      final rows = await _api.rpc('account_files', {'p_profile': profileId});
      final byBucket = <String, List<String>>{};
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        byBucket
            .putIfAbsent(m['bucket'] as String, () => [])
            .add(m['path'] as String);
      }

      final removed = <String, int>{};
      try {
        final result = await _api.rpc('account_delete', {
          'p_profile': profileId,
        });
        final counts = Map<String, dynamic>.from(result as Map)['removed'];
        if (counts is Map) {
          counts.forEach((k, v) => removed['$k'] = (v as num).toInt());
        }
      } on PostgrestException catch (e) {
        if (!e.message.contains('not_found')) rethrow;
      }

      for (final e in byBucket.entries) {
        try {
          final done = (await _api.removeFiles(e.key, e.value)).toSet();
          for (final p in e.value) {
            if (!done.contains(p)) failed.add('${e.key}/$p');
          }
        } catch (_) {
          for (final p in e.value) {
            failed.add('${e.key}/$p');
          }
        }
      }
      return DeleteResult(removed: removed, failedPaths: failed);
    } on PostgrestException catch (e) {
      throw AccountException(e.message, e.message);
    }
  }
}
