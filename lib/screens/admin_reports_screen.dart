import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/report_repository.dart';
import '../util/friendly_error.dart';
import '../util/period_filter.dart';
import '../widgets/error_view.dart';
import '../widgets/filter_dropdown.dart';

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
  String _type = kAllFilter;
  String _reason = kAllFilter;
  String _period = kAllTime;
  final _search = TextEditingController();
  late Future<List<AdminReport>> _future;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Search and filters run on the list already loaded: title, owner, notes
  /// and reason names; Type, Period and Reason narrow it. The reason filter only applies to open reports (the
  /// Hidden list carries no reasons).
  List<AdminReport> _visible(List<AdminReport> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((r) {
      if (!inPeriod(r.lastReported, _period)) return false;
      if (_type != kAllFilter && reportTargetLabel(r.targetType) != _type) {
        return false;
      }
      if (!_hidden &&
          _reason != kAllFilter &&
          !r.reasons.any((e) => e.label == _reason)) {
        return false;
      }
      if (q.isEmpty) return true;
      return [
        r.title,
        r.ownerName,
        r.hiddenReason,
        ...r.notes,
        ...r.reasons.map((e) => e.label),
      ].any((v) => (v ?? '').toLowerCase().contains(q));
    }).toList();
  }

  void _reload() => setState(() {
    _future = _fetch();
  });

  Future<List<AdminReport>> _fetch() =>
      widget.repository.reports(widget.adminId, hidden: _hidden);

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

  Future<void> _suspend(AdminReport r) async {
    final controller = TextEditingController();
    final sender = r.targetType == ReportTarget.contactRequest;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(
              sender ? 'Suspend the sender?' : 'Suspend this person?',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'They cannot sign in and disappear from the Directory until '
                  'you lift the suspension. Their posts and businesses stay as '
                  'they are: hide those separately if needed.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Reason (kept for admins)',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
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
                child: const Text('Suspend'),
              ),
            ],
          ),
        );
      },
    );
    if (reason == null) return;
    await _run(
      r,
      () => widget.repository.suspendUser(widget.adminId, r, reason),
      'Suspended. They cannot sign in.',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                TextField(
                  key: const Key('admin-report-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search title, owner, note or reason...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear search',
                            onPressed: _search.clear,
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: KeyedSubtree(
                        key: const Key('admin-report-type'),
                        child: FilterDropdown(
                          label: 'Type',
                          value: _type,
                          options: [
                            kAllFilter,
                            for (final t in ReportTarget.values)
                              reportTargetLabel(t),
                          ],
                          onChanged: (v) => setState(() => _type = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: KeyedSubtree(
                        key: const Key('admin-report-period'),
                        child: FilterDropdown(
                          label: 'Period',
                          value: _period,
                          options: kPeriodOptions,
                          onChanged: (v) => setState(() => _period = v),
                        ),
                      ),
                    ),
                    if (!_hidden) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: KeyedSubtree(
                          key: const Key('admin-report-reason'),
                          child: FilterDropdown(
                            label: 'Reason',
                            value: _reason,
                            options: [
                              kAllFilter,
                              for (final e in ContentReportReason.values)
                                e.label,
                            ],
                            onChanged: (v) => setState(() => _reason = v),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
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
                final all = snap.data ?? const <AdminReport>[];
                if (all.isEmpty) {
                  return Center(
                    child: Text(
                      _hidden ? 'Nothing is hidden.' : 'No open reports.',
                    ),
                  );
                }
                final items = _visible(all);
                if (items.isEmpty) {
                  return const Center(child: Text('Nothing matches.'));
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
                      onSuspend: () => _suspend(r),
                      onUnsuspend: () => _run(
                        r,
                        () =>
                            widget.repository.unsuspendUser(widget.adminId, r),
                        'Suspension lifted. They can sign in again.',
                      ),
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
    required this.onSuspend,
    required this.onUnsuspend,
    required this.onRestore,
  });

  final AdminReport report;
  final bool hiddenView;
  final bool busy;
  final VoidCallback onDismiss;
  final VoidCallback onActioned;
  final VoidCallback onHide;
  final VoidCallback onSuspend;
  final VoidCallback onUnsuspend;
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
                '${r.targetType == ReportTarget.profile ? 'Suspended' : 'Hidden'}'
                '${r.hiddenReason != null ? ': ${r.hiddenReason}' : ''}',
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
                  if (r.canSuspend && !r.isHidden)
                    FilledButton(
                      key: Key('suspend-${r.targetId}'),
                      onPressed: busy ? null : onSuspend,
                      child: const Text('Suspend user'),
                    ),
                ],
                if (r.isHidden && r.targetType == ReportTarget.profile)
                  FilledButton(
                    key: Key('unsuspend-${r.targetId}'),
                    onPressed: busy ? null : onUnsuspend,
                    child: const Text('Lift suspension'),
                  )
                else if (r.isHidden)
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
