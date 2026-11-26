import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../nav/back_guard.dart';
import '../util/app_language.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import '../widgets/responsive_page.dart';
import '../widgets/job_status_chip.dart';
import 'job_detail_screen.dart';

/// "Lamaran saya": the jobs I applied to, newest first. A job the poster
/// closed is marked "Ditutup"; one hidden by an admin is marked "Tidak
/// tersedia" and cannot be opened. A job that was deleted also deletes its
/// applications, so it no longer appears here.
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({
    super.key,
    required this.currentUser,
    this.fetch,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// Injectable for tests: rows of `{applied_at, job}`.
  final Future<List<Map<String, dynamic>>> Function(String myId)? fetch;

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  String get _myId => widget.currentUser.value['id'] as String;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final custom = widget.fetch;
    if (custom != null) return custom(_myId);
    final rows = await Supabase.instance.client.rpc(
      'my_job_applications',
      params: {'p_applicant': _myId},
    );
    return List<Map<String, dynamic>>.from(
      (rows as List).map((r) => Map<String, dynamic>.from(r as Map)),
    );
  }

  void _reload() => setState(() {
    _future = _load();
  });

  static String _date(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Lamaran saya'))),
      body: ResponsivePage(
        builder: (_, _) => SafeArea(
          top: false,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErrorView(
                  message: friendlyLoadError('your applications', snap.error),
                  screen: 'My applications',
                  error: snap.error,
                  onRetry: _reload,
                );
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr(
                        'Kamu belum melamar lowongan apa pun. Lowongan yang '
                        'kamu lamar akan muncul di sini.',
                      ),
                      key: const Key('my-applications-empty'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  try {
                    await _future;
                  } catch (_) {}
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final job = Map<String, dynamic>.from(r['job'] as Map);
                    final hidden = job['hidden_at'] != null;
                    final closed = jobIsClosed(job);
                    final status = hidden
                        ? 'Tidak tersedia'
                        : closed
                        ? 'Ditutup'
                        : 'Masih dibuka';
                    return Card(
                      key: Key('application-${job['id']}'),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: ListTile(
                        title: Text(job['title'] as String? ?? ''),
                        subtitle: Text(
                          [
                            job['company'] as String? ?? '',
                            'Dilamar ${_date(r['applied_at'])}',
                            status,
                          ].where((s) => s.isNotEmpty).join(' · '),
                        ),
                        trailing: hidden
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: hidden
                            ? null
                            : () => Navigator.of(context).push(
                                AppRoute(
                                  builder: (_) => JobDetailScreen(
                                    job: job,
                                    currentUser: widget.currentUser,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
