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

  // Farrel, 24 Nov 2026 (Android Chrome, after posting a product): the app was
  // drawn in the top half of the screen with grey below. The keyboard height
  // had been kept as the app height after the keyboard closed. Flutter only
  // measures again on a resize event, so the guard sends one when the app is
  // shorter than the screen and nobody is typing.
  group('the app fills the screen again after the keyboard closes', () {
    test('it compares the app height with the screen height', () {
      expect(js, contains("querySelector('flutter-view')"));
      expect(js, contains('function viewTooShort()'));
    });

    test(
      'it asks Flutter to measure again, but not while typing or zoomed',
      () {
        expect(js, contains("dispatchEvent(new Event('resize'))"));
        expect(js, contains('typing() || zoomed() || !viewTooShort()'));
      },
    );

    test('it checks after a field is left, a resize, a tap and a return', () {
      for (final event in [
        "'focusout'",
        "'touchstart'",
        "'visibilitychange'",
        "'pageshow'",
      ]) {
        expect(js, contains(event), reason: event);
      }
      expect(js, contains('fitViewSoon('));
    });

    test('its own resize event does not start the check again', () {
      expect(js, contains('if (nudging) return;'));
    });
  });
}
