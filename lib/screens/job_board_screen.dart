import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'job_detail_screen.dart';
import 'post_job_screen.dart';

/// Job board list view (Day 5) + navigation to job detail (Day 6). Free
/// browsing for everyone — the contact button / visual paywall lives on
/// JobDetailScreen.
class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key, required this.currentProfile});

  /// The verified alumnus currently using the app — needed so a posted job
  /// records who posted it.
  final Map<String, dynamic> currentProfile;

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchJobs();
  }

  Future<List<Map<String, dynamic>>> _fetchJobs() async {
    final rows = await Supabase.instance.client
        .from('job_posts')
        .select('*, poster:alumni_profiles(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _postJob() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PostJobScreen(posterId: widget.currentProfile['id'] as String),
      ),
    );
    if (posted == true) {
      setState(() => _future = _fetchJobs());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Board')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _postJob,
        icon: const Icon(Icons.add),
        label: const Text('Post a Job'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load job board: ${snapshot.error}'),
              ),
            );
          }

          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No jobs posted yet. Be the first alumnus to post one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _JobCard(
              job: jobs[i],
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JobDetailScreen(
                      job: jobs[i],
                      currentProfile: widget.currentProfile,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final Map<String, dynamic> job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poster = job['poster'] as Map<String, dynamic>?;
    final posterName = poster?['name'] as String? ?? 'Alumni';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job['title'] as String? ?? '',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  job['company'] as String? ?? '',
                  if ((job['industry'] as String?)?.isNotEmpty == true)
                    job['industry'] as String,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if ((job['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(
                  job['description'] as String,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Posted by $posterName',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
