import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lock/app_entry.dart';
import 'lock/lock_overlay.dart';
import 'lock/lock_service.dart';
import 'platform/app_location.dart';
import 'theme.dart';
import 'util/app_language.dart';
import 'widgets/marketplace_demo_notice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter web draws on a canvas. Without this, screen readers see an empty
  // page until a hidden "Enable accessibility" button is activated.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  if (kIsWeb) {
    // Clean addresses (/members, not /#/members). Vercel sends every path to
    // index.html (vercel.json), so a refresh on any of them loads the app.
    usePathUrlStrategy();
    // Remembered for the app shell, which opens that tab after the PIN.
    AppLocation.initialPath =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  }
  await dotenv.load(fileName: '.env');

  // These three do not depend on each other, so they run side by side and
  // the first screen shows sooner.
  await Future.wait([
    Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    ),
    // Read the saved "Tutup" answer before any marketplace screen is built.
    MarketplaceDemoNotice.preload(),
    AppLanguage.shared.load(),
  ]);

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
    return MaterialApp(
      title: 'Lingkaran by Ikafe UNDIP',
      theme: AppTheme.light(),
      navigatorKey: _navigatorKey,
      // Covers the app with the lock screen after it has been in the
      // background for a while (device convenience lock, see README).
      builder: (context, child) => LockOverlay(
        lock: LockService.shared,
        navigatorKey: _navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      // Always start at the entry (welcome, PIN or the app), whatever the
      // address is. The shell reads AppLocation.initialPath itself, so a
      // deep address never skips the PIN screen.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute(builder: (_) => const AppEntry()),
      ],
      onGenerateRoute: (_) =>
          MaterialPageRoute(builder: (_) => const AppEntry()),
    );
  }
}
