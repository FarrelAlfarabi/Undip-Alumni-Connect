import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../util/friendly_error.dart';
import '../util/period_filter.dart';
import '../widgets/error_view.dart';
import '../widgets/filter_dropdown.dart';

/// Admin Announcements: past posts with search and a Period filter, and a
/// button to post a new one. Reached only from the Admin home; the database
/// refuses the post for anyone who is not in app_admins.
class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  late Future<List<AdminAnnouncement>> _future;
  final _search = TextEditingController();
  String _period = kAllTime;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.announcements(widget.adminId);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _future = widget.repository.announcements(widget.adminId);
  });

  List<AdminAnnouncement> _visible(List<AdminAnnouncement> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((a) {
      if (!inPeriod(a.createdAt, _period)) return false;
      if (q.isEmpty) return true;
      return [
        a.title,
        a.body,
        a.postedByName,
      ].any((v) => (v ?? '').toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _new() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnnouncementFormScreen(
          adminId: widget.adminId,
          repository: widget.repository,
        ),
      ),
    );
    if (posted == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('announcement-new'),
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: const Text('New announcement'),
      ),
      body: FutureBuilder<List<AdminAnnouncement>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              message: snap.error is AdminException
                  ? adminErrorMessage(snap.error!)
                  : friendlyLoadError('announcements', snap.error),
              screen: 'Admin announcements',
              error: snap.error,
              onRetry: _reload,
            );
          }
          final items = snap.data ?? const [];
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
                        key: const Key('admin-announcements-search'),
                        controller: _search,
                        hintText: 'Search title, message or poster...',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: KeyedSubtree(
                        key: const Key('admin-announcements-period'),
                        child: FilterDropdown(
                          label: 'Period',
                          value: _period,
                          options: kPeriodOptions,
                          onChanged: (v) => setState(() => _period = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text(
                          items.isEmpty
                              ? 'No announcements yet.'
                              : 'Nothing matches.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            _AnnouncementTile(a: shown[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.a});

  final AdminAnnouncement a;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = a.createdAt.toLocal();
    return Card(
      key: Key('announcement-${a.id}'),
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
              a.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}'
              ' · ${a.postedByName ?? 'Admin'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(a.body, maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

const kAnnouncementTitleMax = 120;
const kAnnouncementBodyMax = 2000;

/// The post form. Pops `true` after the database accepted the post.
class AnnouncementFormScreen extends StatefulWidget {
  const AnnouncementFormScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.repository.createAnnouncement(
        widget.adminId,
        title: _title.text,
        body: _body.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(
        context,
        message: adminErrorMessage(e),
        screen: 'New announcement',
        error: e,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New announcement')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('announcement-title'),
                  controller: _title,
                  maxLength: kAnnouncementTitleMax,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a title.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('announcement-body'),
                  controller: _body,
                  maxLength: kAnnouncementBodyMax,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter the message.' : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Every member sees this in Announcements right away. '
                  'It cannot be edited or removed from the app.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('announcement-submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Post announcement'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
