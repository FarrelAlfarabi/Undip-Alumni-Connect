import 'package:supabase_flutter/supabase_flutter.dart';

import 'ikafe_contact.dart';

/// The table is not there yet (migration not applied).
class IkafeTableMissing implements Exception {
  const IkafeTableMissing();
}

/// Thin seam over Supabase so the screen can be tested with a fake.
abstract class IkafeContactApi {
  /// Active rows, as stored.
  Future<List<Map<String, dynamic>>> activeRows();
}

class SupabaseIkafeContactApi implements IkafeContactApi {
  SupabaseIkafeContactApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> activeRows() async {
    try {
      final rows = await _client
          .from('ikafe_contacts')
          .select('id, kind, label, value, sort_order, active')
          .eq('active', true)
          .order('sort_order');
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') {
        throw const IkafeTableMissing();
      }
      rethrow;
    }
  }
}

class IkafeContactList {
  const IkafeContactList(this.contacts, {this.isPlaceholder = false});
  final List<IkafeContact> contacts;

  /// True when these are the built-in example rows.
  final bool isPlaceholder;
}

class IkafeContactRepository {
  IkafeContactRepository([IkafeContactApi? api])
    : _api = api ?? SupabaseIkafeContactApi();

  final IkafeContactApi _api;

  Future<IkafeContactList> load() async {
    try {
      final rows = await _api.activeRows();
      final list = [for (final r in rows) ?IkafeContact.tryFromMap(r)]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return IkafeContactList(list);
    } on IkafeTableMissing {
      return const IkafeContactList(
        kPlaceholderIkafeContacts,
        isPlaceholder: true,
      );
    }
  }
}
