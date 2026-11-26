import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// docs/BACK_MAP.md lists what Back does on every screen. A new screen must
/// be added there, and a removed one taken out, so the map never goes stale.
void main() {
  final classes = <String>{
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart')))
      ...RegExp(
        r'^class (_?[A-Za-z]+Screen)\b',
        multiLine: true,
      ).allMatches(f.readAsStringSync()).map((m) => m.group(1)!),
  };
  final mapText = File('docs/BACK_MAP.md').readAsStringSync();
  final mapped = RegExp(
    r'\b_?[A-Z][A-Za-z]*Screen\b',
  ).allMatches(mapText).map((m) => m.group(0)!).toSet();

  test('every screen is in the Back map', () {
    expect(
      classes.difference(mapped),
      isEmpty,
      reason: 'add these screens to docs/BACK_MAP.md',
    );
  });

  test('the Back map names only screens that exist', () {
    expect(
      mapped.difference(classes),
      isEmpty,
      reason: 'remove these from docs/BACK_MAP.md',
    );
  });

  test('screens with their own PopScope are marked "own steps"', () {
    final marked = RegExp(
      r'\b(_?[A-Z][A-Za-z]*Screen)\b[^|\n]*\*\*own steps\*\*',
    ).allMatches(mapText).map((m) => m.group(1)!).toSet();
    final scoped = <String>{};
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      if (!text.contains('PopScope')) continue;
      // The screen whose build uses PopScope: every Screen class in the file
      // that is not only a helper is fine to require; keep the list exact.
      scoped.addAll(
        RegExp(r'^class (_?[A-Za-z]+Screen) extends State(?:ful)?Widget',
                multiLine: true)
            .allMatches(text)
            .map((m) => m.group(1)!),
      );
    }
    // HomeShell is not a *Screen and is described by the tab rule.
    expect(marked, containsAll(scoped.intersection(mapped).where(
      (c) => const {
        'ApplyJobScreen',
        'PinSettingsScreen',
        'AdminMemberEditScreen',
      }.contains(c),
    )));
  });
}
