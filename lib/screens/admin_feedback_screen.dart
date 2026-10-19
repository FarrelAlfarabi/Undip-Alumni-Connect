import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../util/friendly_error.dart';
import '../util/period_filter.dart';
import '../widgets/error_view.dart';
import '../widgets/filter_dropdown.dart';

/// Feedback inbox: what testers sent from the "Send feedback" button, newest
/// first, with the number of new items. Mark each as seen or done. There is
/// no notification for feedback.
class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  late Future<List<FeedbackItem>> _future;
  final _busy = <String>{};
  final _search = TextEditingController();
  String _status = kAllFilter;
  String _period = kAllTime;

  static const _statuses = [kAllFilter, 'new', 'seen', 'done'];

  @override
  void initState() {
    super.initState();
    _future = widget.repository.feedback(widget.adminId);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FeedbackItem> _visible(List<FeedbackItem> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((f) {
      if (_status != kAllFilter && f.status != _status) return false;
      if (!inPeriod(f.createdAt, _period)) return false;
      if (q.isEmpty) return true;
      return [
        f.profileName,
        f.message,
        f.errorText,
        f.screen,
        f.platform,
      ].any((v) => (v ?? '').toLowerCase().contains(q));
    }).toList();
  }

  void _reload() => setState(() {
    _future = widget.repository.feedback(widget.adminId);
  });

  Future<void> _set(FeedbackItem f, String status) async {
    setState(() => _busy.add(f.id));
    try {
      await widget.repository.setFeedbackStatus(widget.adminId, f.id, status);
      if (!mounted) return;
      _busy.remove(f.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(f.id));
      showErrorSnackBar(
        context,
        message: adminErrorMessage(e),
        screen: 'Feedback inbox',
        error: e,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: FutureBuilder<List<FeedbackItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              message: snap.error is AdminException
                  ? adminErrorMessage(snap.error!)
                  : friendlyLoadError('feedback', snap.error),
              screen: 'Feedback inbox',
              error: snap.error,
              onRetry: _reload,
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No feedback yet.'));
          }
          final shown = _visible(items);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ClearableSearchField(
                        key: const Key('admin-feedback-search'),
                        controller: _search,
                        hintText: 'Search message, name or screen...',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilterDropdown(
                        label: 'Status',
                        value: _status,
                        options: _statuses,
                        onChanged: (v) => setState(() => _status = v),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 200,
                    child: KeyedSubtree(
                      key: const Key('admin-feedback-period'),
                      child: FilterDropdown(
                        label: 'Period',
                        value: _period,
                        options: kPeriodOptions,
                        onChanged: (v) => setState(() => _period = v),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('Nothing matches.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _FeedbackCard(
                          item: shown[i],
                          busy: _busy.contains(shown[i].id),
                          onSeen: () => _set(shown[i], 'seen'),
                          onDone: () => _set(shown[i], 'done'),
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

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.item,
    required this.busy,
    required this.onSeen,
    required this.onDone,
  });

  final FeedbackItem item;
  final bool busy;
  final VoidCallback onSeen;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = item;
    final when = f.createdAt.toLocal();
    return Card(
      key: Key('feedback-${f.id}'),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${f.screen ?? 'Unknown screen'} · ${f.profileName ?? 'Not verified'}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!f.isNew)
                  Chip(
                    label: Text(f.status),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Text(
              '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')} '
              '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'
              ' · v${f.appVersion ?? '?'} (build ${f.buildNumber ?? '?'}) · ${f.platform ?? '?'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if ((f.errorText ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Error: ${f.errorText}'),
            ],
            if ((f.message ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('"${f.message}"'),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (f.status != 'seen')
                  OutlinedButton(
                    key: Key('seen-${f.id}'),
                    onPressed: busy ? null : onSeen,
                    child: const Text('Mark as seen'),
                  ),
                if (f.status != 'done')
                  FilledButton(
                    key: Key('done-${f.id}'),
                    onPressed: busy ? null : onDone,
                    child: const Text('Mark as done'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
