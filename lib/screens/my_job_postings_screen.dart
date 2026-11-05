import 'package:flutter/material.dart';

import '../util/app_language.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../util/friendly_error.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/error_view.dart';
import 'job_applicants_screen.dart';
import 'post_job_screen.dart';

/// The jobs I posted, newest first, with how many people applied. Tap one to
/// see its applicants.
class MyJobPostingsScreen extends StatefulWidget {
  const MyJobPostingsScreen({
    super.key,
    required this.currentUser,
    this.fetch,
    this.deleteJob,
    this.rpc,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// Injectable for tests: returns my jobs, each with an `applicant_count`.
  final Future<List<Map<String, dynamic>>> Function(String myId)? fetch;

  /// Injectable for tests: deletes one of my jobs.
  final Future<void> Function(String myId, String jobId)? deleteJob;

  /// Injectable for tests: runs a database function (close, edit).
  final Future<void> Function(String function, Map<String, dynamic> params)?
  rpc;

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
      final apps = await client.rpc(
        'job_applicant_counts',
        params: {'p_poster': myId},
      );
      for (final a in apps as List) {
        final m = a as Map;
        counts[m['job_post_id'] as String] = (m['applicant_count'] as num)
            .toInt();
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

  Future<void> _delete(Map<String, dynamic> j) async {
    final ok = await confirmDelete(
      context,
      title: tr('Hapus lowongan ini?'),
      body: '"${j['title']}" dan semua lamarannya akan dihapus permanen.',
    );
    if (!ok || !mounted) return;
    try {
      final custom = widget.deleteJob;
      if (custom != null) {
        await custom(_myId, j['id'] as String);
      } else {
        await Supabase.instance.client.rpc(
          'job_post_delete',
          params: {'p_owner': _myId, 'p_job': j['id']},
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Lowongan dihapus.'))));
      _reload();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          message: friendlyError(e),
          screen: 'My job postings',
          error: e,
        );
      }
    }
  }

  Future<void> _call(String function, Map<String, dynamic> params) async {
    final custom = widget.rpc;
    if (custom != null) return custom(function, params);
    await Supabase.instance.client.rpc(function, params: params);
  }

  Future<void> _toggleClosed(Map<String, dynamic> j) async {
    final close = j['closed_at'] == null;
    try {
      await _call('job_post_set_closed', {
        'p_owner': _myId,
        'p_job': j['id'],
        'p_closed': close,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            close
                ? 'Lowongan ditutup. Tidak tampil lagi di Jobs.'
                : 'Lowongan dibuka lagi.',
          ),
        ),
      );
      _reload();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          message: friendlyError(e),
          screen: 'My job postings',
          error: e,
        );
      }
    }
  }

  Future<void> _edit(Map<String, dynamic> j) async {
    final title = TextEditingController(text: j['title'] as String? ?? '');
    final company = TextEditingController(text: j['company'] as String? ?? '');
    final desc = TextEditingController(text: j['description'] as String? ?? '');
    final contact = TextEditingController(
      text: j['contact_info'] as String? ?? '',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Ubah lowongan')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (key, label, c, lines) in [
                ('edit-title', 'Judul', title, 1),
                ('edit-company', 'Perusahaan', company, 1),
                ('edit-description', 'Deskripsi', desc, 5),
                ('edit-contact', 'Kontak', contact, 1),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    key: Key(key),
                    controller: c,
                    maxLines: lines,
                    decoration: InputDecoration(
                      labelText: label,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            key: const Key('edit-save'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Simpan')),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    try {
      await _call('job_post_update', {
        'p_owner': _myId,
        'p_job': j['id'],
        'p_title': title.text,
        'p_company': company.text,
        'p_description': desc.text,
        'p_contact': contact.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Lowongan diperbarui.'))));
      _reload();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          message: friendlyError(e),
          screen: 'My job postings',
          error: e,
        );
      }
    }
  }

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
      appBar: AppBar(title: Text(tr('My job postings'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _post,
        icon: const Icon(Icons.add),
        label: Text(tr('Post a Job')),
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
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  tr(
                    'You have not posted a job yet. Jobs you post show up here '
                    'with the people who applied.',
                  ),
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
                        if (j['closed_at'] != null) 'Ditutup',
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('edit-job-${j['id']}'),
                          tooltip: tr('Ubah lowongan'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(j),
                        ),
                        IconButton(
                          key: Key('close-job-${j['id']}'),
                          tooltip: j['closed_at'] == null
                              ? 'Tutup lowongan'
                              : 'Buka lagi',
                          icon: Icon(
                            j['closed_at'] == null
                                ? Icons.lock_outline
                                : Icons.lock_open_outlined,
                          ),
                          onPressed: () => _toggleClosed(j),
                        ),
                        IconButton(
                          key: Key('delete-job-${j['id']}'),
                          tooltip: tr('Hapus lowongan'),
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () => _delete(j),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JobApplicantsScreen(job: j),
                      ),
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
