import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every text box a person can type a long text into has a limit that matches
/// the database, so a too long text is stopped while typing and not refused
/// later with "Terjadi kesalahan" (found in the bug hunt of 26 Nov 2026: a
/// 260 character job title only said "Gagal memasang").
///
/// Search boxes, the sign in code and the "type this word to confirm" boxes
/// stay free.
const _free = {
  'admin-jobs-search',
  'log-search',
  'admin-report-search',
  'admin-business-search',
  'products-search',
  'admin-confirm-word',
  'delete-field',
};

void main() {
  test('every text box has a length limit', () {
    final bad = <String>[];
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final s = f.readAsStringSync();
      for (final m in RegExp(r'\b(TextField|TextFormField)\(').allMatches(s)) {
        var depth = 0;
        var j = m.end - 1;
        for (; j < s.length; j++) {
          if (s[j] == '(') depth++;
          if (s[j] == ')' && --depth == 0) break;
        }
        final block = s.substring(m.start, j + 1);
        if (block.contains('maxLength') ||
            block.contains('inputFormatters') ||
            block.contains('Length is checked on save')) {
          continue;
        }
        final key = RegExp(r"Key\('([^']*)'\)").firstMatch(block)?.group(1);
        if (key != null && _free.contains(key)) continue;
        // The shared search box widget.
        if (f.path.endsWith('filter_dropdown.dart')) continue;
        final line = s.substring(0, m.start).split('\n').length;
        bad.add('${f.path}:$line ${key ?? ''}');
      }
    }
    expect(bad, isEmpty, reason: 'No limit: ${bad.join(', ')}');
  });
}
