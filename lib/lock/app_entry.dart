import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/verification_screen.dart';
import '../screens/welcome_screen.dart';
import 'lock_screen.dart';
import 'lock_service.dart';
import 'session.dart';

typedef ProfileFetcher = Future<Map<String, dynamic>?> Function(String id);

Future<Map<String, dynamic>?> defaultProfileFetcher(String id) async {
  final row = await Supabase.instance.client
      .from('alumni_profiles')
      .select()
      .eq('id', id)
      .maybeSingle();
  return row == null ? null : Map<String, dynamic>.from(row);
}

/// The signed-in Supabase Auth user's id, or null when there is no session
/// (or Supabase is not initialised, as in widget tests).
typedef SessionUserReader = String? Function();

String? defaultSessionUserId() {
  try {
    return Supabase.instance.client.auth.currentSession?.user.id;
  } catch (_) {
    return null;
  }
}

/// Finds the alumni profile linked to a Supabase Auth user id.
typedef SessionProfileFetcher = Future<Map<String, dynamic>?> Function(
  String userId,
);

Future<Map<String, dynamic>?> defaultFetchProfileForUser(String userId) async {
  final row = await Supabase.instance.client
      .from('alumni_profiles')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
  return row == null ? null : Map<String, dynamic>.from(row);
}

const String kSignInFailedNotice =
    "We couldn't sign you in on this device. Please verify again.";
const String kTooManyPinsNotice = 'Too many wrong PINs. Please verify again.';

/// The app's first screen. A person already verified on this device sees the
/// lock screen; everyone else sees the Welcome screen, as before.
class AppEntry extends StatefulWidget {
  const AppEntry({
    super.key,
    this.lock,
    this.fetchProfile = defaultProfileFetcher,
    this.sessionUserId = defaultSessionUserId,
    this.fetchProfileForUser = defaultFetchProfileForUser,
    this.homeBuilder = defaultHomeBuilder,
    this.clock = DateTime.now,
  });

  final LockService? lock;
  final ProfileFetcher fetchProfile;

  /// Injectable for tests; defaults to the live Supabase Auth session.
  final SessionUserReader sessionUserId;
  final SessionProfileFetcher fetchProfileForUser;
  final HomeBuilder homeBuilder;
  final DateTime Function() clock;

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  late final LockService _lock = widget.lock ?? LockService.shared;
  late Future<RememberedUser?> _remembered = _load();
  String? _notice;

  Future<RememberedUser?> _load() async {
    RememberedUser? remembered;
    try {
      remembered = await _lock.load();
    } catch (_) {
      remembered = null; // unreadable secure storage: behave like a new user
    }
    if (remembered == null) await _restoreFromSession();
    return remembered;
  }

  /// Nobody is remembered on this device (always the case on web, where the
  /// lock is off), but a real Supabase Auth session may have survived the
  /// restart: go straight back into the app for the profile linked to it. A
  /// session whose profile cannot be found is stale, so end it.
  Future<void> _restoreFromSession() async {
    final userId = widget.sessionUserId();
    if (userId == null) return;
    Map<String, dynamic>? profile;
    try {
      profile = await widget.fetchProfileForUser(userId);
    } catch (_) {
      return; // can't tell right now: fall back to the Welcome screen
    }
    if (profile == null) {
      await endAuthSession();
      return;
    }
    final linked = profile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      enterApp(context, linked, lock: _lock, homeBuilder: widget.homeBuilder);
    });
  }

  void _showWelcome([String? notice]) {
    setState(() {
      _notice = notice;
      _remembered = Future.value(null);
    });
  }

  Future<void> _unlock(RememberedUser user) async {
    try {
      // The PIN only unlocks a real sign-in: no live session, or a session
      // for someone else, means verifying again.
      final userId = widget.sessionUserId();
      final profile = await widget.fetchProfile(user.profileId);
      if (userId == null ||
          profile == null ||
          profile['verification_status'] != 'verified' ||
          profile['user_id'] != userId) {
        throw StateError('profile unavailable');
      }
      if (!mounted) return;
      enterApp(context, profile, lock: _lock, homeBuilder: widget.homeBuilder);
    } catch (_) {
      // Profile gone, not verified, no matching session, or the fetch failed:
      // forget this device and its session.
      await _lock.clear();
      await endAuthSession();
      if (mounted) _showWelcome(kSignInFailedNotice);
    }
  }

  Future<void> _forget([String? notice]) async {
    await _lock.clear();
    await endAuthSession();
    if (mounted) _showWelcome(notice);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RememberedUser?>(
      future: _remembered,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return WelcomeScreen(notice: _notice);
        return LockScreen(
          lock: _lock,
          user: user,
          clock: widget.clock,
          onUnlocked: () => _unlock(user),
          onSwitchAccount: _forget,
          onForgotPin: _forget,
          onLockedOut: () => _forget(kTooManyPinsNotice),
          onContinue: () async {
            // No PIN was set: re-run verification.
            await signOutTo(context, const VerificationScreen(), lock: _lock);
          },
        );
      },
    );
  }
}
