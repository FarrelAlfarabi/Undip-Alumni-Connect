import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Who I blocked. Thin seam over the database functions.
abstract class BlockApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);
}

class SupabaseBlockApi implements BlockApi {
  SupabaseBlockApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);
}

class BlockedPerson {
  const BlockedPerson({required this.id, required this.name});
  final String id;
  final String name;
}

class BlockRepository {
  BlockRepository([BlockApi? api]) : _api = api ?? SupabaseBlockApi();
  final BlockApi _api;

  Future<void> block(String blockerId, String blockedId) async {
    await _api.rpc('user_block', {
      'p_blocker': blockerId,
      'p_blocked': blockedId,
    });
  }

  Future<void> unblock(String blockerId, String blockedId) async {
    await _api.rpc('user_unblock', {
      'p_blocker': blockerId,
      'p_blocked': blockedId,
    });
  }

  Future<List<BlockedPerson>> list(String blockerId) async {
    final rows = await _api.rpc('user_blocks_list', {'p_blocker': blockerId});
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .map(
          (m) => BlockedPerson(
            id: m['blocked_id'] as String,
            name: m['name'] as String? ?? 'Alumni',
          ),
        )
        .toList();
  }
}

/// The ONE helper every list uses to leave out people I blocked (Directory,
/// Nearby, jobs, products, businesses). The app asks the database once per
/// session, then filters in memory.
///
/// Honest limit: with no real login this is a comfort feature for honest
/// users, not security. Admin screens do not use it and still show
/// everything.
class BlockList {
  BlockList([BlockRepository? repository]) : _repo = repository;

  /// For tests: already loaded with [ids].
  BlockList.preloaded(Set<String> ids) : _repo = null {
    blocked.value = ids;
  }

  static BlockList _shared = BlockList();
  static BlockList get shared => _shared;

  @visibleForTesting
  static set shared(BlockList value) => _shared = value;

  BlockRepository? _repo;
  Future<void>? _loading;
  String? _viewerId;

  /// Ids of the people I blocked.
  final ValueNotifier<Set<String>> blocked = ValueNotifier(const {});

  BlockRepository get _repository => _repo ??= BlockRepository();

  /// Loads the list for [viewerId] (once per session, or again on [reload]).
  Future<void> load(String viewerId) {
    _viewerId = viewerId;
    return _loading = _fetch(viewerId);
  }

  Future<void> reload() {
    final id = _viewerId;
    if (id == null) return Future.value();
    return load(id);
  }

  Future<void> _fetch(String viewerId) async {
    try {
      final people = await _repository.list(viewerId);
      blocked.value = {for (final p in people) p.id};
    } catch (_) {
      // A failed load only means nothing is filtered.
    }
  }

  /// Lists call this before they filter, so they never show blocked people
  /// just because they were built before the list arrived.
  Future<void> ensureLoaded() => _loading ?? Future.value();

  bool isBlocked(String? id) => id != null && blocked.value.contains(id);

  /// Leaves out every item whose owner I blocked.
  List<T> filter<T>(Iterable<T> items, String? Function(T item) ownerId) => [
    for (final i in items)
      if (!isBlocked(ownerId(i))) i,
  ];

  Future<void> block(String blockerId, String blockedId) async {
    await _repository.block(blockerId, blockedId);
    blocked.value = {...blocked.value, blockedId};
  }

  Future<void> unblock(String blockerId, String blockedId) async {
    await _repository.unblock(blockerId, blockedId);
    blocked.value = {...blocked.value}..remove(blockedId);
  }
}
