import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The repo holds demo data only. Real people's personal addresses (gmail and
/// similar) must not be in seeds, tests, docs or code. Use example.com.
/// This does not clean git history; see docs/BETA_RULES.md.
void main() {
  test('no personal email addresses in tracked text files', () {
    final personal = RegExp(
      r'[A-Za-z0-9._%+-]+@(gmail|yahoo|hotmail|outlook|icloud|live|proton|protonmail)\.[a-z.]+',
      caseSensitive: false,
    );
    const textExt = {
      '.sql',
      '.md',
      '.dart',
      '.yml',
      '.yaml',
      '.txt',
      '.sh',
      '.json',
      '.kts',
    };
    const skipDirs = {'.git', 'build', '.dart_tool', 'node_modules', '.idea'};
    final hits = <String>[];

    void walk(Directory dir) {
      for (final e in dir.listSync(followLinks: false)) {
        final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (e is Directory) {
          if (!skipDirs.contains(name)) walk(e);
        } else if (e is File) {
          final dot = name.lastIndexOf('.');
          if (dot < 0 || !textExt.contains(name.substring(dot))) continue;
          if (name == 'pubspec.lock') continue;
          final text = e.readAsStringSync();
          for (final m in personal.allMatches(text)) {
            hits.add('${e.path}: ${m.group(0)}');
          }
        }
      }
    }

    walk(Directory('.'));
    // This file names the pattern, not an address.
    expect(
      hits.where((h) => !h.startsWith('./test/no_personal_data_test.dart')),
      isEmpty,
    );
  });

  test('the seeds carry no real full names for the three demo accounts', () {
    final seed = File('supabase/seed.sql').readAsStringSync();
    for (final name in [
      'Farrel Alfarabi Saleh',
      'Gilang Wahyu Prawirasani',
      'Maria Graffeliesta',
    ]) {
      expect(seed, isNot(contains(name)), reason: name);
    }
  });
}
