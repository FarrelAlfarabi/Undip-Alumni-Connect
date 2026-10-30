import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_columns.dart';

/// Longest Bio (also enforced in the database).
const int kBioMax = 200;

/// Stops typing at [max] code points, which is how the database counts
/// (char_length). The default TextField limit counts emoji as one, so a bio
/// full of emoji could pass the field and still be refused on save.
class CodePointLimit extends TextInputFormatter {
  const CodePointLimit(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    final cut = String.fromCharCodes(newValue.text.runes.take(max));
    return TextEditingValue(
      text: cut,
      selection: TextSelection.collapsed(offset: cut.length),
    );
  }
}

/// Longest LinkedIn link (also enforced in the database).
const int kLinkedInMax = 200;

final _linkedInHost = RegExp(
  r'^https://([a-z0-9-]+\.)*linkedin\.com/[^\s<>]*$',
  caseSensitive: false,
);

/// Cleans what someone typed into the LinkedIn box. Empty clears it (null).
/// A link without a scheme gets https://. Only https links on linkedin.com are
/// kept; anything else (another site, http, javascript:) throws a
/// [FormatException].
String? normalizeLinkedInUrl(String input) {
  final t = input.trim();
  if (t.isEmpty) return null;
  final withScheme =
      RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(t)
      ? t
      : 'https://$t';
  if (withScheme.length > kLinkedInMax || !_linkedInHost.hasMatch(withScheme)) {
    throw const FormatException('not a linkedin.com link');
  }
  return withScheme;
}

/// Saves my own profile fields and returns the new row (null when no row
/// matched). Injected into the Bio and LinkedIn screens so tests need no
/// database.
typedef ProfileFieldSaver = Future<Map<String, dynamic>?> Function(
  String profileId,
  Map<String, dynamic> changes,
);

Future<Map<String, dynamic>?> saveProfileFields(
  String profileId,
  Map<String, dynamic> changes,
) async {
  final rows = await Supabase.instance.client
      .from('alumni_profiles')
      .update(changes)
      .eq('id', profileId)
      .select(kProfileColumns);
  final list = rows as List;
  return list.isEmpty ? null : list.first as Map<String, dynamic>;
}
