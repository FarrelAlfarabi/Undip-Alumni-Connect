import '../nav/back_guard.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_api.dart';
import '../data/account_repository.dart';
import '../data/avatar_repository.dart';
import '../data/feedback_repository.dart';
import '../data/profile_columns.dart';
import '../screens/returning_screen.dart';
import '../screens/verification_screen.dart';
import '../screens/welcome_screen.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import 'lock_screen.dart';
import 'pin_setup_screen.dart';
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

// Indonesian, shown through tr() by the Welcome screen.
const String kSignInFailedNotice =
    'Kami tidak bisa memasukkanmu di perangkat ini. Silakan verifikasi lagi.';
const String kSessionExpiredNotice =
    'Sesimu sudah berakhir. Silakan masuk lagi.';
const String kTooManyPinsNotice =
    'PIN salah terlalu sering. Silakan verifikasi lagi.';

/// "Kunci" (web) or "Keluar" (phone) from inside the app.
///
/// Web, with a PIN and a stored sign in: only lock. The sign in stays in the
/// browser and the PIN screen shows, so coming back needs the PIN and not a
/// new email code. To leave completely the person taps "Keluar dari browser
/// ini" in Profile (see [leaveBrowser]) or "Bukan kamu? Ganti akun" there.
///
/// Phones, and web without a PIN or a sign in: a full sign out to
/// [destination], as before.
Future<void> leaveApp(
  BuildContext context,
  Widget destination, {
  LockService? lock,
  LoginApi? login,
  bool web = kIsWeb,
  Widget Function()? entryBuilder,
}) async {
  final l = lock ?? LockService.shared;
  final api = login ?? (kRealLogin ? SupabaseLoginApi() : null);
  var canLock = false;
  if (web && api != null && api.hasSession) {
    try {
      canLock = await l.load() != null && await l.hasPin();
    } catch (_) {
      canLock = false;
    }
  }
  if (!context.mounted) return;
  if (!canLock) {
    await signOutTo(context, destination, lock: l, login: api);
    return;
  }
  l.sessionActive = false;
  FeedbackSession.profileId = null;
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    AppRoute(
      builder: (_) =>
          entryBuilder?.call() ?? AppEntry(lock: l, loginApi: login),
    ),
    (_) => false,
  );
}

/// Web "Keluar dari browser ini": a real sign out. The sign in, the remembered
/// person and the PIN are all removed from this browser, so the next person
/// needs an email code. Goes to the first-time Welcome screen.
Future<void> leaveBrowser(
  BuildContext context, {
  LockService? lock,
  LoginApi? login,
}) => signOutTo(
  context,
  const WelcomeScreen(),
  lock: lock ?? LockService.shared,
  login: login,
  forget: true,
);

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

  /// Web: signed in and no PIN set. No lock screen: straight to making a PIN.
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
        // No PIN to ask for. The stored sign in is the proof, so go on to
        // making a PIN (or, if it has ended, to the returning screen) without
        // another code.
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
    if (widget.web && !await _lock.hasPin()) {
      // Web: everyone has a PIN, so "Keluar" can come back with the PIN and
      // not with another email code. Someone who removed theirs makes a new
      // one here.
      if (!mounted) return false;
      final ready = profile;
      Navigator.of(context).pushReplacement(
        AppRoute(
          builder: (_) => PinSetupScreen(
            lock: _lock,
            onDone: (ctx) async => enterApp(
              ctx,
              ready,
              lock: _lock,
              homeBuilder: widget.homeBuilder,
              accountRepository: widget.accountRepository,
            ),
          ),
        ),
      );
      return true;
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
    try {
      // "Ganti akun", "Lupa PIN" and the 5th wrong PIN end the sign in too,
      // so nothing of this person is left in the browser or on the phone.
      await _login?.signOut();
    } catch (_) {
      // The local wipe below still happens.
    }
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
