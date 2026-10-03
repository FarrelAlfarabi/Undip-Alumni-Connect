import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard: no fee or commission wording anywhere in the app's
/// source. (Listing prices are fine; a fee on top of them is not something
/// the app offers.)
void main() {
  test('no fee, commission or service-charge wording in lib/', () {
    final banned = RegExp(
      r'commission|\bfees?\b|service charge|platform fee|admin fee|biaya',
      caseSensitive: false,
    );
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
