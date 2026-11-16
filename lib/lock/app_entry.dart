import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_api.dart';
import '../data/account_repository.dart';
import '../data/avatar_repository.dart';
import '../data/profile_columns.dart';
import '../screens/returning_screen.dart';
import '../screens/verification_screen.dart';
import '../screens/welcome_screen.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import 'lock_screen.dart';
import 'lock_service.dart';
import 'session.dart';

typedef ProfileFetcher = Future<Map<String, dynamic>?> Function(String id);

Future<Map<String, dynamic>?> defaultProfileFetcher(String id) async {
  final row = await Supabase.instance.client
      .from('alumni_profiles')
      .select(kProfileColumns)
      .eq('id', id)
      .maybeSingle();
  if (row == null) return null;
  final urls = await AvatarRepository().urlsById(id: id);
  return {...row, if (urls[id] != null) 'avatar_url': urls[id]};
}

const String kSignInFailedNotice =
    "We couldn't sign you in on this device. Please verify again.";
const String kSessionExpiredNotice =
    'Your sign in expired. Please sign in again.';
const String kTooManyPinsNotice = 'Too many wrong PINs. Please verify again.';

/// The app's first screen. A person already verified on this device sees the
/// lock screen; everyone else sees the Welcome screen, as before.
class AppEntry extends StatefulWidget {
  const AppEntry({
    super.key,
    this.lock,
    this.fetchProfile = defaultProfileFetcher,
    this.homeBuilder = defaultHomeBuilder,
    this.clock = DateTime.now,
    this.accountRepository,
    this.loginApi,
    this.web = kIsWeb,
  });

  /// Browser behaviour: a stored sign in opens the app without a new email
  /// code (the PIN screen comes first when a PIN is set), and a person whose
  /// sign in expired sees a "welcome back" screen instead of the first-time
  /// Welcome. Phones keep their own flow. Tests pass it.
  final bool web;

  /// Real login only: a remembered person still needs a stored sign in.
  final LoginApi? loginApi;

  /// Injectable for tests (consent is saved through it).
  final AccountRepository? accountRepository;

  final LockService? lock;
  final ProfileFetcher fetchProfile;
  final HomeBuilder homeBuilder;
  final DateTime Function() clock;

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  late final LockService _lock = widget.lock ?? LockService.shared;
  late Future<RememberedUser?> _remembered = _load();
  String? _notice;

  /// Web: first name of a person whose sign in expired here. Picks the
  /// returning screen. It never opens the app.
  String? _returning;

  /// Web: signed in and no PIN set, so the app opens without a tap.
  bool _entering = false;

  LoginApi? get _login =>
      widget.loginApi ?? (kRealLogin ? SupabaseLoginApi() : null);

  Future<RememberedUser?> _load() async {
    try {
      final user = await _lock.load();
      if (!widget.web) return user;
      if (user == null) {
        _returning = await _lock.returningName();
        return null;
      }
      if (_login != null && !await _lock.hasPin()) {
        // No PIN to ask for. The stored sign in is the proof, so go in (or,
        // if it has ended, to the returning screen) without another code.
        _entering = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _autoEnter(user));
      }
      return user;
    } catch (_) {
      return null; // unreadable secure storage: behave like a new user
    }
  }

  Future<void> _autoEnter(RememberedUser user) async {
    if (!mounted) return;
    final entered = await _unlock(user);
    // Not in (for example offline): show the screen with "Lanjut" to retry.
    if (!entered && mounted) setState(() => _entering = false);
  }

  void _showWelcome([String? notice]) {
    setState(() {
      _notice = notice;
      _entering = false;
      _remembered = Future.value(null);
    });
  }

  /// Returns true when the app was opened.
  Future<bool> _unlock(RememberedUser user) async {
    final login = _login;
    if (login != null && !login.hasSession) {
      // The sign in expired or was removed: the PIN alone is not enough, so
      // the person signs in again. Same as Sign out: the PIN stays with its
      // owner, so they enter it instead of making a new one.
      await _lock.signOut();
      if (widget.web) {
        await _lock.markReturning(user.displayName);
        _returning = await _lock.returningName();
      }
      if (mounted) _showWelcome(kSessionExpiredNotice);
      return false;
    }
    Map<String, dynamic>? profile;
    try {
      profile = await widget.fetchProfile(user.profileId);
    } catch (e) {
      // A network or server error says nothing about the profile. Keep the
      // PIN and the remembered person, and let them try again.
      if (!mounted) return false;
      showErrorSnackBar(
        context,
        message: friendlyError(e),
        screen: 'Unlock',
        error: e,
      );
      return false;
    }
    if (profile == null || profile['verification_status'] != 'verified') {
      // The profile is really gone or no longer verified: forget this device.
      await _lock.clear();
      if (mounted) _showWelcome(kSignInFailedNotice);
      return false;
    }
    if (!mounted) return false;
    enterApp(
      context,
      profile,
      lock: _lock,
      homeBuilder: widget.homeBuilder,
      accountRepository: widget.accountRepository,
    );
    return true;
  }

  Future<void> _forget([String? notice]) async {
    await _lock.clear();
    _returning = null;
    if (mounted) _showWelcome(notice);
  }

  Future<void> _notMe() async {
    await _lock.clearReturning();
    _returning = null;
    if (mounted) _showWelcome();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RememberedUser?>(
      future: _remembered,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || _entering) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) {
          final name = _returning;
          if (widget.web && name != null) {
            return ReturningScreen(name: name, onNotYou: _notMe);
          }
          return WelcomeScreen(notice: _notice);
        }
        return LockScreen(
          lock: _lock,
          user: user,
          clock: widget.clock,
          onUnlocked: () => _unlock(user),
          onSwitchAccount: _forget,
          onForgotPin: _forget,
          onLockedOut: () => _forget(kTooManyPinsNotice),
          onContinue: () async {
            if (widget.web && _login?.hasSession == true) {
              // Web, still signed in: try again to open the app.
              await _unlock(user);
              return;
            }
            // No PIN was set: re-run verification.
            await signOutTo(context, const VerificationScreen(), lock: _lock);
          },
        );
      },
    );
  }
}
