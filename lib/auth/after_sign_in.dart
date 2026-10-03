import 'package:flutter/material.dart';

import '../lock/lock_screen.dart';
import '../lock/lock_service.dart';
import '../lock/pin_setup_screen.dart';
import '../lock/session.dart';

/// What happens once someone is signed in with their alumni profile.
///
/// Remember this person on the device (id, name and a masked email hint
/// only). If they already made a PIN on this device (they signed out and are
/// back), ask for it; otherwise offer to create one. Then go into the app. If
/// the lock storage fails for any reason, skip the lock and go straight in:
/// sign-in itself already succeeded.
///
/// [signInBuilder] builds a fresh sign-in screen, for "Forgot PIN" and
/// "Switch account", which wipe the local data and start over.
Future<void> afterSignIn(
  BuildContext context,
  Map<String, dynamic> profile,
  String email, {
  required Widget Function() signInBuilder,
  LockService? lock,
  HomeBuilder homeBuilder = defaultHomeBuilder,
}) async {
  final service = lock ?? LockService.shared;
  var offerPin = false;
  RememberedUser? askForPin;
  try {
    if (service.enabled) {
      await service.remember(
        profileId: profile['id'] as String,
        displayName: profile['name'] as String? ?? '',
        email: email,
      );
      if (await service.hasPin()) {
        askForPin = await service.load();
      } else {
        offerPin = true;
      }
    }
  } catch (_) {
    offerPin = false;
    askForPin = null;
  }
  if (!context.mounted) return;

  if (askForPin != null) {
    _askForExistingPin(
      context,
      service,
      askForPin,
      profile,
      signInBuilder,
      homeBuilder,
    );
    return;
  }
  if (!offerPin) {
    enterApp(context, profile, lock: service, homeBuilder: homeBuilder);
    return;
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => PinSetupScreen(
        lock: service,
        // The setup screen is replaced by the app once done or skipped.
        onDone: (setupContext) async => enterApp(
          setupContext,
          profile,
          lock: service,
          homeBuilder: homeBuilder,
        ),
      ),
    ),
  );
}

// Same screen as the launch lock. Forgot PIN, Switch account and five wrong
// tries wipe the local data and start sign-in again, as at launch.
void _askForExistingPin(
  BuildContext context,
  LockService lock,
  RememberedUser user,
  Map<String, dynamic> profile,
  Widget Function() signInBuilder,
  HomeBuilder homeBuilder,
) {
  final navigator = Navigator.of(context);

  Future<void> startOver() async {
    await endAuthSession();
    try {
      await lock.clear();
    } catch (_) {
      // The screen change below still starts sign-in again.
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => signInBuilder()),
      (_) => false,
    );
  }

  Future<void> enter(BuildContext lockContext) async =>
      enterApp(lockContext, profile, lock: lock, homeBuilder: homeBuilder);

  navigator.pushReplacement(
    MaterialPageRoute(
      builder: (lockContext) => LockScreen(
        lock: lock,
        user: user,
        onUnlocked: () => enter(lockContext),
        onSwitchAccount: startOver,
        onForgotPin: startOver,
        onLockedOut: startOver,
        onContinue: () => enter(lockContext),
      ),
    ),
  );
}
