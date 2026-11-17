import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/app_language.dart';

/// The ONE rule for the phone Back button and the browser Back button.
///
/// Back pops the top pop-up or sheet, then the pushed screen, then (inside
/// the app shell) returns to the previous tab, then Home. Only a screen that
/// is the first route of the app (Home, or Welcome, PIN and the other screens
/// before sign in) has nothing left to pop. There, on a phone, the first Back
/// shows [kExitHint] and a second Back within [window] leaves the app. In a
/// browser Back there never leaves the app by itself.
///
/// [AppRoute] applies this to every screen. Never call
/// `SystemNavigator.pop()` anywhere else (a test enforces it).
class BackGuard {
  BackGuard._();

  /// Indonesian text, shown through tr().
  static const String kExitHint = 'Tekan sekali lagi untuk keluar';

  /// Time allowed between the two presses.
  static const Duration window = Duration(seconds: 2);

  /// True while the lock screen covers the app. The screens under it must not
  /// react to Back then, or Back would pop a screen nobody can see.
  static final ValueNotifier<bool> locked = ValueNotifier(false);

  /// Replaced by tests.
  static void Function() exitApp = SystemNavigator.pop;
  static DateTime Function() clock = DateTime.now;
  static bool web = kIsWeb;

  static DateTime? _lastPress;
  static OverlayEntry? _toast;
  static Timer? _timer;

  static void reset() {
    exitApp = SystemNavigator.pop;
    clock = DateTime.now;
    web = kIsWeb;
    locked.value = false;
    _lastPress = null;
    _hideToast();
  }

  static void _hideToast() {
    _timer?.cancel();
    _timer = null;
    _toast?.remove();
    _toast = null;
  }

  /// Back on a screen that has nothing to pop. Never exits on the first press.
  static void rootBack(NavigatorState? navigator) {
    // A browser tab is closed by the person, never by Back.
    if (web) return;
    final now = clock();
    final last = _lastPress;
    if (last != null && now.difference(last) <= window) {
      _lastPress = null;
      _hideToast();
      exitApp();
      return;
    }
    _lastPress = now;
    _showToast(navigator);
  }

  static void _showToast(NavigatorState? navigator) {
    final overlay = navigator?.overlay;
    if (overlay == null) return;
    _hideToast();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: 96,
        child: IgnorePointer(
          child: Center(
            child: Material(
              key: const Key('exit-hint'),
              color: const Color(0xE6222222),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  tr(kExitHint),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _toast = entry;
    overlay.insert(entry);
    _timer = Timer(window, _hideToast);
  }
}

/// The only page route the app uses. Same as [MaterialPageRoute], plus the
/// central Back rule: when it is the first route (or the lock screen covers
/// the app) it declares that it handles Back itself, so Android does not
/// close the app before the app is asked.
class AppRoute<T> extends MaterialPageRoute<T> {
  AppRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  RoutePopDisposition get popDisposition {
    if (isFirst || BackGuard.locked.value) return RoutePopDisposition.doNotPop;
    return super.popDisposition;
  }

  @override
  void onPopInvokedWithResult(bool didPop, T? result) {
    if (didPop) {
      super.onPopInvokedWithResult(didPop, result);
      return;
    }
    // The lock screen covers the app: nothing under it may react to Back.
    if (BackGuard.locked.value) {
      BackGuard.rootBack(navigator);
      return;
    }
    // A screen with its own PopScope (the shell with its tabs) decides first.
    final scoped = super.popDisposition == RoutePopDisposition.doNotPop;
    super.onPopInvokedWithResult(didPop, result);
    if (!scoped && isFirst) BackGuard.rootBack(navigator);
  }
}
