import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/account_repository.dart';
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
      .select()
      .eq('id', id)
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
    this.homeBuilder = defaultHomeBuilder,
    this.clock = DateTime.now,
    this.accountRepository,
  });

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

  Future<RememberedUser?> _load() async {
    try {
      return await _lock.load();
    } catch (_) {
      return null; // unreadable secure storage: behave like a new user
    }
  }

  void _showWelcome([String? notice]) {
    setState(() {
      _notice = notice;
      _remembered = Future.value(null);
    });
  }

  Future<void> _unlock(RememberedUser user) async {
    Map<String, dynamic>? profile;
    try {
      profile = await widget.fetchProfile(user.profileId);
    } catch (e) {
      // A network or server error says nothing about the profile. Keep the
      // PIN and the remembered person, and let them try again.
      if (!mounted) return;
      showErrorSnackBar(
        context,
        message: friendlyError(e),
        screen: 'Unlock',
        error: e,
      );
      return;
    }
    if (profile == null || profile['verification_status'] != 'verified') {
      // The profile is really gone or no longer verified: forget this device.
      await _lock.clear();
      if (mounted) _showWelcome(kSignInFailedNotice);
      return;
    }
    if (!mounted) return;
    enterApp(
      context,
      profile,
      lock: _lock,
      homeBuilder: widget.homeBuilder,
      accountRepository: widget.accountRepository,
    );
  }

  Future<void> _forget([String? notice]) async {
    await _lock.clear();
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
