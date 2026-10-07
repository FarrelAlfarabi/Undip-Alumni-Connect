import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import 'job_applicants_screen.dart';
import 'post_job_screen.dart';

/// The jobs I posted, newest first, with how many people applied. Tap one to
/// see its applicants.
class MyJobPostingsScreen extends StatefulWidget {
  const MyJobPostingsScreen({super.key, required this.currentUser, this.fetch});

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// Injectable for tests: returns my jobs, each with an `applicant_count`.
  final Future<List<Map<String, dynamic>>> Function(String myId)? fetch;

  @override
  State<MyJobPostingsScreen> createState() => _MyJobPostingsScreenState();
}

class _MyJobPostingsScreenState extends State<MyJobPostingsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  String get _myId => widget.currentUser.value['id'] as String;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final custom = widget.fetch;
    if (custom != null) return custom(_myId);
    return _fetchMine(_myId);
  }

  static Future<List<Map<String, dynamic>>> _fetchMine(String myId) async {
    final client = Supabase.instance.client;
    final rows = List<Map<String, dynamic>>.from(
      await client
              .from('job_posts')
              .select()
              .eq('posted_by', myId)
              .order('created_at', ascending: false)
          as List,
    );
    if (rows.isEmpty) return rows;
    // One query for all counts. A failure only hides the numbers.
    final counts = <String, int>{};
    try {
      final apps = await client
          .from('job_applications')
          .select('job_post_id')
          .inFilter('job_post_id', [for (final r in rows) r['id']]);
      for (final a in apps as List) {
        final id = (a as Map)['job_post_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
    } catch (_) {
      return rows;
    }
    return [
      for (final r in rows) {...r, 'applicant_count': counts[r['id']] ?? 0},
    ];
  }

  void _reload() => setState(() {
    _future = _load();
  });

  Future<void> _post() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PostJobScreen(posterId: _myId)),
    );
    if (posted == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My job postings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _post,
        icon: const Icon(Icons.add),
        label: const Text('Post a Job'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              message: friendlyLoadError('your job postings', snap.error),
              screen: 'My job postings',
              error: snap.error,
              onRetry: _reload,
            );
          }
          final jobs = snap.data ?? const [];
          if (jobs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You have not posted a job yet. Jobs you post show up here '
                  'with the people who applied.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final j = jobs[i];
              final hidden = j['hidden_at'] != null;
              final n = j['applicant_count'] as int?;
              return Card(
                key: Key('my-job-${j['id']}'),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: ListTile(
                  title: Text(j['title'] as String? ?? ''),
                  subtitle: Text(
                    [
                      j['company'] as String? ?? '',
                      if (n != null)
                        '$n ${n == 1 ? 'applicant' : 'applicants'}',
                      if (hidden) 'Hidden by an admin',
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => JobApplicantsScreen(job: j),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
