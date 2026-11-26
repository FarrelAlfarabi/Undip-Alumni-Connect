import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/config/feature_flags.dart';

/// Web basics from the legal and accessibility audit: the page says which
/// language it is in, and Flutter web (which draws on a canvas) turns on its
/// accessibility tree at start-up, so screen readers do not see an empty page.
void main() {
  test('web/index.html declares the page language', () {
    final html = File('web/index.html').readAsStringSync();
    expect(RegExp(r'<html[^>]*\slang="en"').hasMatch(html), isTrue);
  });

  test('always-on semantics is a flag, off for now, and still wired in', () {
    // Temporary choice (26 Nov 2026): off to save 35 to 45% of scrolling and
    // loading time. Flip with --dart-define=ALWAYS_ON_SEMANTICS=true.
    expect(kAlwaysOnSemantics, isFalse);
    final main = File('lib/main.dart').readAsStringSync();
    expect(
      RegExp(
        r'if\s*\(\s*kIsWeb\s*&&\s*kAlwaysOnSemantics\s*\)\s*SemanticsBinding\.instance\.ensureSemantics\(\)',
      ).hasMatch(main),
      isTrue,
    );
  });

  test('the Vercel build can switch always-on semantics back on', () {
    final sh = File('scripts/vercel-build.sh').readAsStringSync();
    expect(sh, contains('ALWAYS_ON_SEMANTICS'));
  });
}
