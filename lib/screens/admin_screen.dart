import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/marketplace_repository.dart';
import '../models/business.dart';
import '../util/friendly_error.dart';
import 'admin_feedback_screen.dart';
import 'admin_reports_screen.dart';
import 'marketplace_admin_screen.dart';
import '../widgets/error_view.dart';

/// Admin home: one entry per area. Reached from Profile > Admin, which shows
/// only when the database says this profile is an admin.
class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.adminId,
    this.adminRepository,
    this.marketplaceRepository,
    this.extraSections = const [],
  });

  final String adminId;
  final AdminRepository? adminRepository;
  final MarketplaceRepository? marketplaceRepository;

  /// Sections added by later features.
  final List<AdminSection> extraSections;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminRepository _admin =
      widget.adminRepository ?? AdminRepository();
  late final MarketplaceRepository _market =
      widget.marketplaceRepository ?? MarketplaceRepository();
  late Future<int> _newFeedback;
  late Future<int> _unseenReports;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  void _loadCount() {
    _newFeedback = _admin.newFeedbackCount(widget.adminId).catchError((_) => 0);
    _unseenReports = _admin
        .unseenReportsCount(widget.adminId)
        .catchError((_) => 0);
  }

  @override
  Widget build(BuildContext context) {
    final adminId = widget.adminId;
    final sections = [
      ...widget.extraSections,
      AdminSection(
        key: 'admin-reports',
        icon: Icons.flag_outlined,
        title: 'Reports',
        subtitle: 'Reported content: dismiss, hide, restore',
        showsReportsCount: true,
        builder: (_) =>
            AdminReportsScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-feedback',
        icon: Icons.feedback_outlined,
        title: 'Feedback',
        subtitle: 'What testers sent from the Send feedback button',
        showsFeedbackCount: true,
        builder: (_) =>
            AdminFeedbackScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-businesses',
        icon: Icons.business_center_outlined,
        title: 'Businesses',
        subtitle: 'Approve, reject, suspend or restore',
        builder: (_) =>
            AdminBusinessesScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-marketplace',
        icon: Icons.storefront_outlined,
        title: 'Marketplace review',
        subtitle: 'Old listings waiting for review, report counts',
        builder: (_) =>
            MarketplaceAdminScreen(adminId: adminId, repository: _market),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final s in sections)
            Card(
              key: Key(s.key),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                leading: Icon(s.icon),
                title: Text(s.title),
                subtitle: Text(s.subtitle),
                trailing: s.showsFeedbackCount
                    ? FutureBuilder<int>(
                        future: _newFeedback,
                        builder: (context, snap) {
                          final n = snap.data ?? 0;
                          return Badge(
                            key: const Key('feedback-badge'),
                            isLabelVisible: n > 0,
                            label: Text('$n'),
                            child: const Icon(Icons.chevron_right),
                          );
                        },
                      )
                    : s.showsReportsCount
                    ? FutureBuilder<int>(
                        future: _unseenReports,
                        builder: (context, snap) {
                          final n = snap.data ?? 0;
                          return Badge(
                            key: const Key('reports-badge'),
                            isLabelVisible: n > 0,
                            label: Text('$n'),
                            child: const Icon(Icons.chevron_right),
                          );
                        },
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: s.builder));
                  if (mounted) setState(_loadCount);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class AdminSection {
  const AdminSection({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.showsFeedbackCount = false,
    this.showsReportsCount = false,
  });

  final String key;
  final bool showsFeedbackCount;

  /// Shows the number of reports no admin has seen yet.
  final bool showsReportsCount;
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

/// Businesses: pending first. Approve (choose the band), reject (reason),
/// suspend, restore. Only status and the approved band change here.
class AdminBusinessesScreen extends StatefulWidget {
  const AdminBusinessesScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  static const _filters = <(String label, String? status)>[
    ('Pending', 'pending'),
    ('Approved', 'approved'),
    ('Rejected', 'rejected'),
    ('Suspended', 'suspended'),
    ('All', null),
  ];

  String? _status = 'pending';
  late Future<List<Business>> _future;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _future = widget.repository.businesses(widget.adminId, status: _status);
  }

  void _reload() => setState(() {
    _future = widget.repository.businesses(widget.adminId, status: _status);
  });

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(
    Business b,
    Future<Business> Function() action,
    String done,
  ) async {
    setState(() => _busy.add(b.id));
    try {
      await action();
      if (!mounted) return;
      _toast(done);
      _busy.remove(b.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(b.id));
      showErrorSnackBar(
        context,
        message: adminErrorMessage(e),
        screen: 'Admin businesses',
        error: e,
      );
    }
  }

  Future<void> _approve(Business b) async {
    final band = await showDialog<BusinessBand>(
      context: context,
      builder: (ctx) => _BandDialog(initial: b.requestedBand),
    );
    if (band == null) return;
    await _run(
      b,
      () => widget.repository.approve(widget.adminId, b.id, band),
      'Approved ${b.name} as ${band.label}.',
    );
  }

  Future<void> _reject(Business b) async {
    final reason = await _askReason(
      title: 'Reject business',
      label: 'Reason (shown to the owner)',
      required: true,
      action: 'Reject',
    );
    if (reason == null) return;
    await _run(
      b,
      () => widget.repository.reject(widget.adminId, b.id, reason),
      'Rejected ${b.name}.',
    );
  }

  Future<void> _suspend(Business b) async {
    final reason = await _askReason(
      title: 'Suspend business',
      label: 'Reason (shown to the owner, optional)',
      required: false,
      action: 'Suspend',
    );
    if (reason == null) return;
    await _run(
      b,
      () => widget.repository.suspend(widget.adminId, b.id, reason: reason),
      'Suspended ${b.name}. Its products are hidden.',
    );
  }

  Future<void> _restore(Business b) => _run(
    b,
    () => widget.repository.restore(widget.adminId, b.id),
    'Restored ${b.name}.',
  );

  Future<String?> _askReason({
    required String title,
    required String label,
    required bool required,
    required String action,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: label,
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
                  if (required && t.isEmpty) {
                    setLocal(() => error = 'A reason is required');
                    return;
                  }
                  Navigator.of(ctx).pop(t);
                },
                child: Text(action),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Businesses')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$1),
                      selected: _status == f.$2,
                      onSelected: (_) {
                        _status = f.$2;
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Business>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErrorView(
                    message: snap.error is AdminException
                        ? adminErrorMessage(snap.error!)
                        : friendlyLoadError('businesses', snap.error),
                    screen: 'Admin businesses',
                    error: snap.error,
                    onRetry: _reload,
                  );
                }
                final items = snap.data ?? const [];
                if (items.isEmpty) {
                  return const Center(child: Text('Nothing here.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _AdminBusinessCard(
                    business: items[i],
                    busy: _busy.contains(items[i].id),
                    onApprove: () => _approve(items[i]),
                    onReject: () => _reject(items[i]),
                    onSuspend: () => _suspend(items[i]),
                    onRestore: () => _restore(items[i]),
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

class _BandDialog extends StatefulWidget {
  const _BandDialog({this.initial});
  final BusinessBand? initial;

  @override
  State<_BandDialog> createState() => _BandDialogState();
}

class _BandDialogState extends State<_BandDialog> {
  BusinessBand? _band;

  @override
  void initState() {
    super.initState();
    _band = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve with which band?'),
      content: SingleChildScrollView(
        child: RadioGroup<BusinessBand>(
          groupValue: _band,
          onChanged: (v) => setState(() => _band = v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final b in BusinessBand.values)
                RadioListTile<BusinessBand>(
                  key: Key('approve-band-${b.name}'),
                  value: b,
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.label),
                  subtitle: Text(b.range),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _band == null
              ? null
              : () => Navigator.of(context).pop(_band),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

class _AdminBusinessCard extends StatelessWidget {
  const _AdminBusinessCard({
    required this.business,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onRestore,
  });

  final Business business;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSuspend;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = business;
    final actions = <Widget>[
      if (b.status == BusinessStatus.pending) ...[
        OutlinedButton(
          key: Key('reject-${b.id}'),
          onPressed: busy ? null : onReject,
          child: const Text('Reject'),
        ),
        FilledButton(
          key: Key('approve-${b.id}'),
          onPressed: busy ? null : onApprove,
          child: const Text('Approve'),
        ),
      ],
      if (b.status == BusinessStatus.rejected)
        FilledButton(
          key: Key('approve-${b.id}'),
          onPressed: busy ? null : onApprove,
          child: const Text('Approve'),
        ),
      if (b.status == BusinessStatus.approved)
        OutlinedButton(
          key: Key('suspend-${b.id}'),
          onPressed: busy ? null : onSuspend,
          child: const Text('Suspend'),
        ),
      if (b.status == BusinessStatus.suspended)
        FilledButton(
          key: Key('restore-${b.id}'),
          onPressed: busy ? null : onRestore,
          child: const Text('Restore'),
        ),
    ];
    return Card(
      key: Key('admin-business-${b.id}'),
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
              b.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${b.category} · by ${b.ownerName ?? 'Alumni'} · ${b.status.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(b.description),
            const SizedBox(height: 8),
            if (b.socialLink != null)
              Text('Social: ${b.socialLink}', style: theme.textTheme.bodySmall),
            if (b.websiteLink != null)
              Text(
                'Website: ${b.websiteLink}',
                style: theme.textTheme.bodySmall,
              ),
            Text(
              'Band chosen by owner: ${b.requestedBand?.label ?? '-'}'
              '${b.approvedBand != null ? ' · approved: ${b.approvedBand!.label}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (b.rejectionReason != null && b.rejectionReason!.isNotEmpty)
              Text(
                'Reason: ${b.rejectionReason}',
                style: theme.textTheme.bodySmall,
              ),
            if (b.unlimitedUntil != null)
              Text(
                'Unlimited posting until ${b.unlimitedUntil!.toIso8601String().substring(0, 10)} (set in the dashboard)',
                style: theme.textTheme.bodySmall,
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
