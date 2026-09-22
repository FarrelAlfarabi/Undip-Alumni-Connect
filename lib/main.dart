import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNDIP Alumni Connect',
      theme: AppTheme.light(),
      home: const _SessionGate(),
    );
  }
}

/// Restores a real Supabase Auth session on relaunch (real auth, not the
/// old exact-match "verification" — see PROJECT_NOTES.md's
/// production-hardening entry), so a signed-in user lands straight back
/// in the app shell instead of re-verifying every time. Falls back to
/// [WelcomeScreen] when there's no session, or when a session exists but
/// somehow has no linked alumni_profiles row (shouldn't happen in normal
/// use — signs the stale session out rather than getting stuck).
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Future<Map<String, dynamic>?> _restoredProfile = _restoreSession();

  Future<Map<String, dynamic>?> _restoreSession() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return null;

    final profile = await client
        .from('alumni_profiles')
        .select()
        .eq('user_id', session.user.id)
        .maybeSingle();

    if (profile == null) {
      await client.auth.signOut();
      return null;
    }
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _restoredProfile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = snapshot.data;
        if (profile == null) return const WelcomeScreen();
        return HomeShell(profile: profile);
      },
    );
  }
}
