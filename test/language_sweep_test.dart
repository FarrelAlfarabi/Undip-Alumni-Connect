import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/util/strings_en.dart';
import 'package:undip_alumni_connect/util/strings_id.dart';

/// Keeps the language setting honest: text on screen goes through tr()/trf(),
/// and every such text has an entry in one of the two maps.
final _lit = r'''(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")''';
final _keys =
    r'(?:title|subtitle|label|labelText|hintText|helperText|tooltip|message|'
    r'content|semanticLabel|errorText)';

/// Names that stay as they are in both languages (brand, feature names,
/// values). Add here only on purpose.
const _keep = {
  'Home', 'Members', 'Explore', 'Chat', 'Profile', 'Jobs', 'Marketplace',
  'Requests', 'Alumni', 'Business', 'PIN', 'LINGKARAN', 'IKAFE',
  'IKAFE UNDIP', 'Ikafe', 'Lingkaran', 'LinkedIn', 'Email', 'Website', 'Pin',
  'Instagram', 'BETA', 'Listing', 'Messages', 'Portfolio', 'Status', 'Hidden',
  'Photo', 'name@example.com', 'Admin', 'Announcements', 'Directory',
  'Review queue', 'Reports', 'Notifications', 'Business directory',
  'Contact admin', 'Send feedback', 'Post announcement', 'New announcement',
  // Single words that read the same in both languages.
  'Privacy policy and rules',
  'WA: 08xxx',
  '@username or https://instagram.com/...',
  '{0}\n{1}\nEmail: {2}',
  'Band', 'Download', 'Online', 'Menu', 'Info', 'Total',
};

List<File> _sources() => [
  for (final dir in ['lib/screens', 'lib/widgets', 'lib/lock', 'lib/policy'])
    ...Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart')),
]..removeWhere((f) => f.path.contains('policy_text.dart'));

String _decode(String lit) {
  final parts = RegExp(_lit).allMatches(lit).map((m) => m.group(0)!);
  return parts.map((p) => p.substring(1, p.length - 1)).join();
}

void main() {
  test('no plain text on screen without tr()', () {
    final pat = RegExp(
      '(?:\\b$_keys\\s*:\\s*|\\bText\\(\\s*)((?:$_lit\\s*)+)',
      dotAll: true,
    );
    final bad = <String>[];
    for (final f in _sources()) {
      final s = f.readAsStringSync();
      for (final m in pat.allMatches(s)) {
        final text = _decode(m.group(1)!);
        if (!RegExp('[A-Za-z]{3,}').hasMatch(text)) continue;
        if (text.startsWith('http') ||
            (text.contains('/') && !text.contains(' '))) {
          continue;
        }
        if (RegExp(r'^[a-z_\-\.]+$').hasMatch(text)) continue;
        if (text.contains(r'$')) continue; // values: use trf()
        if (_keep.contains(text)) continue;
        final line = s.substring(0, m.start).split('\n').length;
        bad.add('${f.path}:$line "$text"');
      }
    }
    expect(bad, isEmpty, reason: 'wrap with tr(): ${bad.join('\n')}');
  });

  test('every tr() text has an entry in a language map', () {
    final pat = RegExp('\\btrf?\\(\\s*((?:$_lit\\s*)+)', dotAll: true);
    final missing = <String>[];
    for (final f in _sources()) {
      final s = f.readAsStringSync();
      for (final m in pat.allMatches(s)) {
        final text = _decode(m.group(1)!)
            .replaceAll(r"\'", "'")
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\$', r'$');
        if (!RegExp('[A-Za-z]{3,}').hasMatch(text)) continue;
        if (_keep.contains(text)) continue;
        if (kIndonesian.containsKey(text) || kEnglish.containsKey(text)) {
          continue;
        }
        final line = s.substring(0, m.start).split('\n').length;
        missing.add('${f.path}:$line "$text"');
      }
    }
    expect(missing, isEmpty, reason: 'add to the maps: ${missing.join('\n')}');
  });
}
