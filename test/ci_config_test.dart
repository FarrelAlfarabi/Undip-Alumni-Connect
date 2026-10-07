import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Build plumbing guards (see the beta review): Vercel built with whatever
/// "stable" was that day while CI used a pinned version, CI skipped pushes to
/// main, and the SQL tests were never run in CI.
void main() {
  final ci = File('.github/workflows/flutter-ci.yml').readAsStringSync();
  final vercel = File('scripts/vercel-build.sh').readAsStringSync();

  String ciFlutterVersion() {
    final m = RegExp(r'FLUTTER_VERSION:\s*"([0-9.]+)"').firstMatch(ci);
    expect(m, isNotNull, reason: 'FLUTTER_VERSION in the CI file');
    return m!.group(1)!;
  }

  test('Vercel builds with the same Flutter version as CI', () {
    final v = ciFlutterVersion();
    expect(vercel, contains('FLUTTER_VERSION="$v"'));
    expect(vercel, contains(r'-b "$FLUTTER_VERSION"'));
    expect(vercel, isNot(contains('-b stable')));
  });

  test('CI runs on pushes to main, not only pull requests', () {
    expect(
      RegExp(r'push:\s*\n\s*branches:\s*\[\s*main\s*\]').hasMatch(ci),
      isTrue,
    );
  });

  test('CI runs the SQL checks', () {
    expect(ci, contains('supabase/tests/run_fresh_chain.sh'));
    expect(ci, contains('supabase/tests/run_beta_local.sh'));
  });
}
