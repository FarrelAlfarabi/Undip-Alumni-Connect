import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/home_shell.dart';
import 'lock_service.dart';

/// Builds the signed-in app for a profile. Tests pass a stand-in because the
/// real [HomeShell] talks to Supabase.
typedef HomeBuilder = Widget Function(Map<String, dynamic> profile);

Widget defaultHomeBuilder(Map<String, dynamic> profile) =>
    HomeShell(profile: profile);

/// Go into the app for a verified person, replacing the current screen.
void enterApp(
  BuildContext context,
  Map<String, dynamic> profile, {
  LockService? lock,
  HomeBuilder homeBuilder = defaultHomeBuilder,
}) {
  (lock ?? LockService.shared).sessionActive = true;
  Navigator.of(context)
      .pushReplacement(MaterialPageRoute(builder: (_) => homeBuilder(profile)));
}

/// Ends the Supabase Auth session so the device can no longer act as that
/// person. Never throws: with no session (or no Supabase, as in widget
/// tests) there is nothing to end.
Future<void> endAuthSession() async {
  try {
    await Supabase.instance.client.auth
        .signOut()
        .timeout(const Duration(seconds: 5));
  } catch (_) {}
}

/// Sign out on this device: forget the remembered person and PIN, end the
/// Supabase Auth session, then show [destination] with the whole stack torn
/// down.
Future<void> signOutTo(
  BuildContext context,
  Widget destination, {
  LockService? lock,
}) async {
  final navigator = Navigator.of(context);
  try {
    await (lock ?? LockService.shared).clear();
  } catch (_) {
    // Nothing else to do; the screen change below still signs the person out.
  }
  await endAuthSession();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => destination),
    (_) => false,
  );
}
