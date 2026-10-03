import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lock/app_entry.dart';
import 'lock/lock_overlay.dart';
import 'lock/lock_service.dart';
import 'settings/app_settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  AppSettings.shared = await AppSettings.load();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.shared,
      builder: (context, _) => _buildApp(),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: 'Lingkaran',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: AppSettings.shared.themeMode,
      navigatorKey: _navigatorKey,
      // Covers the app with the lock screen after it has been in the
      // background for a while (device convenience lock, see README).
      builder: (context, child) => LockOverlay(
        lock: LockService.shared,
        navigatorKey: _navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppEntry(),
    );
  }
}
