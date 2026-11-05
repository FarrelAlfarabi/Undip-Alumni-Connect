import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../data/admin_repository.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import '../widgets/undo_snackbar.dart';

/// Admin Jobs: every job post, newest first (taken-down ones last). An admin
/// can take any post down with a reason (the poster gets a notice) and put it
/// back. Jobs need no approval, so this is only for moderation.
class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  final _search = TextEditingController();
  late Future<List<AdminJob>> _future;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<AdminJob>> _load() => widget.repository.jobs(
    widget.adminId,
    search: _search.text.trim().isEmpty ? null : _search.text.trim(),
  );

  void _reload() => setState(() {
    _future = _load();
  });

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(tr('Turunkan lowongan ini?')),
            content: TextField(
              key: const Key('job-hide-reason'),
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: tr('Alasan (dikirim ke pemasang)'),
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('Batal')),
              ),
              FilledButton(
                key: const Key('job-hide-confirm'),
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) {
                    setLocal(() => error = 'Alasan wajib diisi');
                    return;
                  }
                  Navigator.of(ctx).pop(t);
                },
                child: Text(tr('Turunkan')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _hide(AdminJob j) async {
    final reason = await _askReason();
    if (reason == null || !mounted) return;
    await _run(
      j,
      () => widget.repository.hideJob(widget.adminId, j.id, reason),
      'Lowongan diturunkan. Pemasang diberi tahu.',
      undo: () => widget.repository.restoreJob(widget.adminId, j.id),
    );
  }

  Future<void> _restore(AdminJob j) => _run(
    j,
    () => widget.repository.restoreJob(widget.adminId, j.id),
    'Lowongan ditampilkan lagi.',
    undo: () => widget.repository.hideJob(
      widget.adminId,
      j.id,
      j.hiddenReason ?? 'Diturunkan oleh admin',
    ),
  );

  Future<void> _run(
    AdminJob j,
    Future<void> Function() action,
    String done, {
    required Future<void> Function() undo,
  }) async {
    setState(() => _busy.add(j.id));
    try {
      await action();
      if (!mounted) return;
      showUndoSnackBar(
        context,
        message: done,
        screen: 'Admin jobs',
        errorText: adminErrorMessage,
        onUndo: () async {
          await undo();
          if (mounted) _reload();
        },
      );
      _reload();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          message: adminErrorMessage(e),
          screen: 'Admin jobs',
          error: e,
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(j.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Jobs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const Key('admin-jobs-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: tr('Cari judul, perusahaan atau pemasang'),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AdminJob>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErrorView(
                    message: friendlyLoadError('lowongan', snap.error),
                    screen: 'Admin jobs',
                    error: snap.error,
                    onRetry: _reload,
                  );
                }
                final items = snap.data ?? const <AdminJob>[];
                if (items.isEmpty) {
                  return Center(child: Text(tr('Belum ada lowongan.')));
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final j = items[i];
                      return Card(
                        key: Key('admin-job-${j.id}'),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                j.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${j.company} · ${j.posterName ?? 'Alumni'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (j.isHidden) ...[
                                const SizedBox(height: 8),
                                Text(
                                  trf('Diturunkan: {0}', [
                                    j.hiddenReason ?? '-',
                                  ]),
                                  key: Key('job-hidden-${j.id}'),
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: j.isHidden
                                    ? OutlinedButton(
                                        key: Key('job-restore-${j.id}'),
                                        onPressed: _busy.contains(j.id)
                                            ? null
                                            : () => _restore(j),
                                        child: Text(tr('Tampilkan lagi')),
                                      )
                                    : TextButton.icon(
                                        key: Key('job-hide-${j.id}'),
                                        onPressed: _busy.contains(j.id)
                                            ? null
                                            : () => _hide(j),
                                        icon: const Icon(Icons.visibility_off),
                                        label: Text(tr('Turunkan')),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.error,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
