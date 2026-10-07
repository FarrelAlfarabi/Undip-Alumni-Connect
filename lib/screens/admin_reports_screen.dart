import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/report_repository.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';

String reportTargetLabel(ReportTarget t) => switch (t) {
  ReportTarget.job => 'Job',
  ReportTarget.product => 'Product',
  ReportTarget.business => 'Business',
  ReportTarget.profile => 'Profile',
  ReportTarget.contactRequest => 'Contact request',
};

/// Admin Reports: open reports (with a preview, how many reports, and the
/// reasons) and everything hidden. Dismiss, hide, restore. Nothing is hidden
/// automatically: an admin decides.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _hidden = false;
  late Future<List<AdminReport>> _future;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  void _reload() => setState(() {
    _future = _fetch();
  });

  // Opening the open-reports list counts as seeing them: the badge on the
  // Admin screen clears. A failure here must not hide the list.
  Future<List<AdminReport>> _fetch() async {
    final items = await widget.repository.reports(
      widget.adminId,
      hidden: _hidden,
    );
    if (!_hidden) {
      try {
        await widget.repository.markReportsSeen(widget.adminId);
      } catch (_) {}
    }
    return items;
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(
    AdminReport r,
    Future<void> Function() action,
    String done,
  ) async {
    setState(() => _busy.add(r.targetId));
    try {
      await action();
      if (!mounted) return;
      _toast(done);
      _busy.remove(r.targetId);
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(r.targetId));
      showErrorSnackBar(
        context,
        message: adminErrorMessage(e),
        screen: 'Admin reports',
        error: e,
      );
    }
  }

  Future<void> _hide(AdminReport r) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Hide this content?'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: 'Reason (shown to the owner)',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) {
                    setLocal(() => error = 'A reason is required');
                    return;
                  }
                  Navigator.of(ctx).pop(t);
                },
                child: const Text('Hide'),
              ),
            ],
          ),
        );
      },
    );
    if (reason == null) return;
    await _run(
      r,
      () => widget.repository.hideContent(widget.adminId, r, reason),
      'Hidden. It no longer shows for anyone.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Open reports')),
                ButtonSegment(value: true, label: Text('Hidden')),
              ],
              selected: {_hidden},
              onSelectionChanged: (s) {
                _hidden = s.first;
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AdminReport>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErrorView(
                    message: snap.error is AdminException
                        ? adminErrorMessage(snap.error!)
                        : friendlyLoadError('reports', snap.error),
                    screen: 'Admin reports',
                    error: snap.error,
                    onRetry: _reload,
                  );
                }
                final items = snap.data ?? const [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      _hidden ? 'Nothing is hidden.' : 'No open reports.',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = items[i];
                    return _ReportCard(
                      report: r,
                      hiddenView: _hidden,
                      busy: _busy.contains(r.targetId),
                      onDismiss: () => _run(
                        r,
                        () =>
                            widget.repository.dismissReports(widget.adminId, r),
                        'Dismissed.',
                      ),
                      onActioned: () => _run(
                        r,
                        () => widget.repository.markActioned(widget.adminId, r),
                        'Marked as handled.',
                      ),
                      onHide: () => _hide(r),
                      onRestore: () => _run(
                        r,
                        () =>
                            widget.repository.restoreContent(widget.adminId, r),
                        'Restored. It shows again.',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.hiddenView,
    required this.busy,
    required this.onDismiss,
    required this.onActioned,
    required this.onHide,
    required this.onRestore,
  });

  final AdminReport report;
  final bool hiddenView;
  final bool busy;
  final VoidCallback onDismiss;
  final VoidCallback onActioned;
  final VoidCallback onHide;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = report;
    return Card(
      key: Key('report-${r.targetType.value}-${r.targetId}'),
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
              '${reportTargetLabel(r.targetType)}: ${r.title}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (r.ownerName != null)
              Text(
                'By ${r.ownerName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 6),
            if (!hiddenView) ...[
              Text(
                '${r.reportCount} ${r.reportCount == 1 ? 'report' : 'reports'}: '
                '${r.reasons.map((e) => e.label).join(', ')}',
              ),
              for (final n in r.notes.take(3))
                Text('"$n"', style: theme.textTheme.bodySmall),
            ],
            if (r.isHidden)
              Text(
                'Hidden${r.hiddenReason != null ? ': ${r.hiddenReason}' : ''}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (!hiddenView) ...[
                  OutlinedButton(
                    key: Key('dismiss-${r.targetId}'),
                    onPressed: busy ? null : onDismiss,
                    child: const Text('Dismiss'),
                  ),
                  if (!r.canHide)
                    OutlinedButton(
                      key: Key('actioned-${r.targetId}'),
                      onPressed: busy ? null : onActioned,
                      child: const Text('Mark as handled'),
                    ),
                  if (r.canHide && !r.isHidden)
                    FilledButton(
                      key: Key('hide-${r.targetId}'),
                      onPressed: busy ? null : onHide,
                      child: const Text('Hide'),
                    ),
                ],
                if (r.isHidden)
                  FilledButton(
                    key: Key('restore-${r.targetId}'),
                    onPressed: busy ? null : onRestore,
                    child: const Text('Restore'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
