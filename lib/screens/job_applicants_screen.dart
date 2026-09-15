import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Applicant list for a job post you own (added 17 Sep 2026, Master Plan
/// §3.4 item 7). Demo-scope stand-in for "notify the poster": there's no
/// real push/email here, this list itself is the notification surface —
/// see job_detail_screen.dart, which shows an applicant count for your
/// own jobs when notify_on_apply is on.
class JobApplicantsScreen extends StatefulWidget {
  const JobApplicantsScreen({super.key, required this.job});

  final Map<String, dynamic> job;

  @override
  State<JobApplicantsScreen> createState() => _JobApplicantsScreenState();
}

class _JobApplicantsScreenState extends State<JobApplicantsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchApplicants();
  }

  Future<List<Map<String, dynamic>>> _fetchApplicants() async {
    final rows = await Supabase.instance.client
        .from('job_applications')
        .select()
        .eq('job_post_id', widget.job['id'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  String? _cvUrl(String? cvPath) {
    if (cvPath == null || cvPath.isEmpty) return null;
    return Supabase.instance.client.storage.from('cvs').getPublicUrl(cvPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Applicants — ${widget.job['title'] as String? ?? ''}'),
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
                child: Text('Failed to load applicants: ${snapshot.error}'),
              ),
            );
          }

          final applicants = snapshot.data ?? [];
          if (applicants.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No applications yet.'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: applicants.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final a = applicants[i];
              final cvUrl = _cvUrl(a['cv_path'] as String?);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['full_name'] as String? ?? '',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a['email'] as String? ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if ((a['phone'] as String?)?.isNotEmpty == true)
                        Text(
                          a['phone'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if ((a['cover_note'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Text(
                          a['cover_note'] as String,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if ((a['linkedin_url'] as String?)?.isNotEmpty ==
                              true)
                            _LinkChip(
                              icon: Icons.link,
                              label: 'LinkedIn',
                              url: a['linkedin_url'] as String,
                            ),
                          if ((a['portfolio_url'] as String?)?.isNotEmpty ==
                              true)
                            _LinkChip(
                              icon: Icons.public,
                              label: 'Portfolio',
                              url: a['portfolio_url'] as String,
                            ),
                          if (cvUrl != null)
                            _LinkChip(
                              icon: Icons.description_outlined,
                              label: 'CV',
                              url: cvUrl,
                            ),
                        ],
                      ),
                    ],
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

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () => launchUrl(Uri.parse(url)),
    );
  }
}
