import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNDIP Alumni Connect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SupabaseStatusPage(),
    );
  }
}

/// Temporary landing page confirming Supabase config is wired up.
/// Will be replaced by real screens once the Supabase project is confirmed.
class SupabaseStatusPage extends StatelessWidget {
  const SupabaseStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final configured =
        dotenv.env['SUPABASE_URL']?.isNotEmpty == true &&
        dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(title: const Text('UNDIP Alumni Connect')),
      body: Center(
        child: Text(
          configured
              ? 'Supabase config loaded ✓'
              : 'Missing SUPABASE_URL / SUPABASE_ANON_KEY in .env',
        ),
      ),
    );
  }
}
