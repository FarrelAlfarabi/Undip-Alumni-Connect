import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Web basics from the legal and accessibility audit: the page says which
/// language it is in, and Flutter web (which draws on a canvas) turns on its
/// accessibility tree at start-up, so screen readers do not see an empty page.
void main() {
  test('web/index.html declares the page language', () {
    final html = File('web/index.html').readAsStringSync();
    expect(RegExp(r'<html[^>]*\slang="en"').hasMatch(html), isTrue);
  });

  test('the web build turns on semantics at start-up', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('SemanticsBinding.instance.ensureSemantics()'));
    expect(
      RegExp(r'if\s*\(\s*kIsWeb\s*\)[^;]*\n?[^;]*ensureSemantics')
          .hasMatch(main),
      isTrue,
    );
  });
}
