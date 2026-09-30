import 'package:flutter/material.dart';

import '../screens/welcome_screen.dart';
import 'app_entry.dart';
import 'lock_config.dart';
import 'lock_screen.dart';
import 'lock_service.dart';

/// Wraps the whole app. When a verified person has been in the background
/// for longer than [timeout], covers the app with the lock screen until they
/// unlock. Does nothing when no PIN is set, before anyone is signed in, or
/// on web.
class LockOverlay extends StatefulWidget {
  const LockOverlay({
    super.key,
    required this.lock,
    required this.navigatorKey,
    required this.child,
    this.timeout = kLockAfterBackground,
    this.clock = DateTime.now,
  });

  final LockService lock;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final Duration timeout;
  final DateTime Function() clock;

  @override
  State<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<LockOverlay> with WidgetsBindingObserver {
  DateTime? _pausedAt;
  RememberedUser? _lockedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= widget.clock();
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      if (at != null && widget.clock().difference(at) > widget.timeout) {
        _maybeLock();
      }
    }
  }

  Future<void> _maybeLock() async {
    final lock = widget.lock;
    if (!lock.enabled || !lock.sessionActive || _lockedFor != null) return;
    try {
      if (!await lock.hasPin()) return;
      final user = await lock.load();
      if (user != null && mounted) setState(() => _lockedFor = user);
    } catch (_) {
      // Cannot read secure storage: leave the app as it is.
    }
  }

  void _unlockedNow() => setState(() => _lockedFor = null);

  /// Wipe local data, drop the overlay and start the first-time flow.
  Future<void> _forget([String? notice]) async {
    await widget.lock.clear();
    if (!mounted) return;
    setState(() => _lockedFor = null);
    widget.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => WelcomeScreen(notice: notice)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _lockedFor;
    return Stack(
      children: [
        // Offstage keeps the app's state (open screens, scroll positions)
        // while hiding it from view, taps and screen readers.
        Offstage(offstage: user != null, child: widget.child),
        if (user != null)
          Positioned.fill(
            child: LockScreen(
              lock: widget.lock,
              user: user,
              clock: widget.clock,
              onUnlocked: () async => _unlockedNow(),
              onSwitchAccount: _forget,
              onForgotPin: _forget,
              onLockedOut: () => _forget(kTooManyPinsNotice),
              onContinue: () async => _unlockedNow(),
            ),
          ),
      ],
    );
  }
}
