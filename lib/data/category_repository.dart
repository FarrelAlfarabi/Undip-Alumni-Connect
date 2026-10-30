import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_listing.dart';

/// The five categories the app shipped with. Used until the `categories`
/// table answers, and whenever it cannot, so the app never shows an empty list.
const List<String> kBuiltInCategories = kMarketplaceCategories;

abstract class CategoryApi {
  /// Rows of `categories`: name, sort_order, active.
  Future<List<Map<String, dynamic>>> fetch();
}

class SupabaseCategoryApi implements CategoryApi {
  SupabaseCategoryApi([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;

  @override
  Future<List<Map<String, dynamic>>> fetch() async {
    final client = _client ?? Supabase.instance.client;
    final rows = await client
        .from('categories')
        .select('name, sort_order, active')
        .eq('active', true);
    return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
  }
}

/// Product and business categories. Loaded once per session. Farrel adds or
/// retires a category in the Supabase dashboard; no app update is needed.
class CategoryRepository {
  CategoryRepository([CategoryApi? api]) : _api = api ?? SupabaseCategoryApi();

  /// The one the screens share.
  static final CategoryRepository shared = CategoryRepository();

  final CategoryApi _api;
  bool _loaded = false;
  Future<List<String>>? _inFlight;

  /// Current list. Screens listen to it so they redraw when the table answers.
  final ValueNotifier<List<String>> names = ValueNotifier(kBuiltInCategories);

  Future<List<String>> load() {
    if (_loaded) return Future.value(names.value);
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<List<String>> _fetch() async {
    try {
      final rows = await _api.fetch();
      final active = rows.where((r) => r['active'] != false).toList()
        ..sort((a, b) {
          final byOrder = _order(a).compareTo(_order(b));
          return byOrder != 0
              ? byOrder
              : '${a['name']}'.compareTo('${b['name']}');
        });
      final list = [for (final r in active) '${r['name']}'];
      if (list.isNotEmpty) names.value = list;
      _loaded = list.isNotEmpty;
    } catch (_) {
      // Keep what we have: the built-in list, or the last good answer.
    }
    return names.value;
  }

  static int _order(Map<String, dynamic> r) =>
      (r['sort_order'] as num?)?.toInt() ?? 100;

  /// Form check. The category an item already has stays valid when it was
  /// retired later, so an old item can still be saved. Only a new choice is
  /// checked against the list (the database does the same).
  String? validate(String? value, {String? current}) {
    if (value == null || value.isEmpty) return 'Choose a category';
    if (value == current || names.value.contains(value)) return null;
    return 'Choose a category from the list';
  }
}
