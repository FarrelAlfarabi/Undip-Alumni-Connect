import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/filter_dropdown.dart';
import 'job_detail_screen.dart';
import 'notifications_screen.dart';
import 'post_job_screen.dart';

/// Job board list view (Day 5) + navigation to job detail (Day 6). Free
/// browsing for everyone — the contact button / visual paywall lives on
/// JobDetailScreen.
///
/// Search + filters (added later) follow the same client-side pattern as
/// the Alumni Directory (directory_screen.dart) — fine for a handful of
/// seed jobs, not meant to scale past the demo.
class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key, required this.currentUser});

  /// The verified alumnus currently using the app, as a shared notifier —
  /// needed so a posted job records who posted it, and so the contact
  /// paywall on JobDetailScreen reflects a subscribe action taken via any
  /// other job or via messaging.
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  final _searchController = TextEditingController();
  String _industry = kAllFilter;
  String _company = kAllFilter;
  Future<int>? _unreadNotificationsFuture;

  @override
  void initState() {
    super.initState();
    _future = _fetchJobs();
    _unreadNotificationsFuture = _fetchUnreadNotificationCount();
    _searchController.addListener(() => setState(() {}));
  }

  Future<int> _fetchUnreadNotificationCount() async {
    final rows = await Supabase.instance.client
        .from('notifications')
        .select('id')
        .eq('recipient_id', widget.currentUser.value['id'])
        .filter('read_at', 'is', null);
    return (rows as List).length;
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          currentUserId: widget.currentUser.value['id'] as String,
        ),
      ),
    );
    if (mounted) {
      setState(
        () => _unreadNotificationsFuture = _fetchUnreadNotificationCount(),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchJobs() async {
    final rows = await Supabase.instance.client
        .from('job_posts')
        .select('*, poster:alumni_profiles(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    final query = _searchController.text.trim().toLowerCase();

    return all.where((j) {
      if (_industry != kAllFilter && j['industry'] != _industry) {
        return false;
      }
      if (_company != kAllFilter && j['company'] != _company) return false;
      if (query.isNotEmpty) {
        final title = (j['title'] as String? ?? '').toLowerCase();
        final company = (j['company'] as String? ?? '').toLowerCase();
        final description = (j['description'] as String? ?? '').toLowerCase();
        if (!title.contains(query) &&
            !company.contains(query) &&
            !description.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchController.text.isNotEmpty ||
      _industry != kAllFilter ||
      _company != kAllFilter;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _industry = kAllFilter;
      _company = kAllFilter;
    });
  }

  Future<void> _postJob() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PostJobScreen(posterId: widget.currentUser.value['id'] as String),
      ),
    );
    if (posted == true) {
      setState(() => _future = _fetchJobs());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Board'),
        actions: [
          FutureBuilder<int>(
            future: _unreadNotificationsFuture,
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return IconButton(
                onPressed: _openNotifications,
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
              );
            },
          ),
        ],
      ),
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

          final all = snapshot.data ?? [];
          if (all.isEmpty) {
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

          final jobs = _applyFilters(all);
          final industries = distinctSortedValues(all, 'industry');
          final companies = distinctSortedValues(all, 'company');

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClearableSearchField(
                  controller: _searchController,
                  hintText: 'Search by title, company, or description...',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilterDropdown(
                        label: 'Industry',
                        value: _industry,
                        options: industries,
                        onChanged: (v) => setState(() => _industry = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilterDropdown(
                        label: 'Company',
                        value: _company,
                        options: companies,
                        onChanged: (v) => setState(() => _company = v),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: ClearFiltersButton(
                  active: _hasActiveFilters,
                  onPressed: _clearFilters,
                ),
              ),
              Expanded(
                child: jobs.isEmpty
                    ? const Center(child: Text('No jobs match these filters.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: jobs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _JobCard(
                          job: jobs[i],
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(
                                  job: jobs[i],
                                  currentUser: widget.currentUser,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
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
