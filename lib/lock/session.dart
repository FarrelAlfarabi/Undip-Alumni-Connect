import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../data/feedback_repository.dart';
import '../policy/consent_screen.dart';
import '../screens/home_shell.dart';
import 'lock_service.dart';

/// Builds the signed-in app for a profile. Tests pass a stand-in because the
/// real [HomeShell] talks to Supabase.
typedef HomeBuilder = Widget Function(Map<String, dynamic> profile);

Widget defaultHomeBuilder(Map<String, dynamic> profile) =>
    HomeShell(profile: profile);

/// Go into the app for a verified person, replacing the current screen.
///
/// If this person has not accepted the CURRENT privacy policy version, the
/// consent screen comes first; without accepting they cannot enter.
void enterApp(
  BuildContext context,
  Map<String, dynamic> profile, {
  LockService? lock,
  HomeBuilder homeBuilder = defaultHomeBuilder,
  AccountRepository? accountRepository,
}) {
  final l = lock ?? LockService.shared;
  if (needsConsent(profile)) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConsentScreen(
          profile: profile,
          lock: l,
          repository: accountRepository,
          onAccepted: (ctx, accepted) => enterApp(
            ctx,
            accepted,
            lock: l,
            homeBuilder: homeBuilder,
            accountRepository: accountRepository,
          ),
        ),
      ),
    );
    return;
  }
  l.sessionActive = true;
  FeedbackSession.profileId = profile['id'] as String?;
  Navigator.of(context)
      .pushReplacement(MaterialPageRoute(builder: (_) => homeBuilder(profile)));
}

/// Sign out on this device: forget the remembered person but keep their PIN
/// (local only, nothing on the server changes), then show [destination] with
/// the whole stack torn down.
Future<void> signOutTo(
  BuildContext context,
  Widget destination, {
  LockService? lock,
}) async {
  final navigator = Navigator.of(context);
  FeedbackSession.profileId = null;
  try {
    await (lock ?? LockService.shared).signOut();
  } catch (_) {
    // Nothing else to do; the screen change below still signs the person out.
  }
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => destination),
    (_) => false,
  );
}
