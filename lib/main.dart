import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/verification_screen.dart';

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

/// Temporary landing page confirming the app reaches the real Supabase
/// database — not real UI. Directory/job board/messaging screens are later.
class SupabaseStatusPage extends StatelessWidget {
  const SupabaseStatusPage({super.key});

  Future<int> _fetchAlumniCount() {
    return supabase.from('alumni_profiles').count(CountOption.exact);
  }

  @override
  Widget build(BuildContext context) {
    final configured =
        dotenv.env['SUPABASE_URL']?.isNotEmpty == true &&
        dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(title: const Text('UNDIP Alumni Connect')),
      body: Center(
        child: !configured
            ? const Text('Missing SUPABASE_URL / SUPABASE_ANON_KEY in .env')
            : FutureBuilder<int>(
                future: _fetchAlumniCount(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Supabase config loaded, but the query failed:\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Connected to Supabase ✓\n'
                        '${snapshot.data} alumni_profiles rows found',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const VerificationScreen(),
                            ),
                          );
                        },
                        child: const Text('Verify Alumni Status'),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
