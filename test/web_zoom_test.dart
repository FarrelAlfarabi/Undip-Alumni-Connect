// Zoom never gets stuck (24 Nov 2026). Flutter replaces the viewport tag with
// maximum-scale=5.0, so phones could zoom in, and a pinch on the Flutter
// canvas never reached the browser to zoom back out. On computers Flutter
// cancelled Ctrl + wheel (trackpad pinch), so browser zoom out did nothing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final js = File('web/viewport_guard.js').readAsStringSync();

  test('the guard acts on every phone and tablet, not only iPhone', () {
    expect(js, contains('Android'));
    expect(js, isNot(contains('if (!isIOS) return;')));
  });

  test('the viewport tag Flutter writes is put back to no zoom', () {
    expect(js, contains('MutationObserver'));
    expect(js, contains('maximum-scale=1.0'));
    expect(js, contains('flt-viewport'));
  });

  test('a zoomed page snaps back, but not while someone is typing', () {
    expect(js, contains('visualViewport'));
    expect(js, contains('function typing()'));
    expect(js, contains('zoomed() && !typing()'));
  });

  test('computers: Ctrl + wheel and trackpad pinch reach the browser', () {
    expect(js, contains("'wheel'"));
    expect(js, contains('e.ctrlKey'));
    expect(js, contains('stopImmediatePropagation'));
    expect(js, contains('capture: true'));
  });
}
