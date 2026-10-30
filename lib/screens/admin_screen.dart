import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/category_repository.dart';
import '../data/marketplace_repository.dart';
import '../models/business.dart';
import '../util/friendly_error.dart';
import '../util/period_filter.dart';
import 'admin_announcements_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_reports_screen.dart';
import 'marketplace_admin_screen.dart';
import '../widgets/business_photo.dart';
import '../widgets/error_view.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/searchable_choice.dart';

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
        builder: (_) =>
            AdminReportsScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-feedback',
        icon: Icons.feedback_outlined,
        title: 'Feedback',
        subtitle: 'What testers sent from the Send feedback button',
        builder: (_) =>
            AdminFeedbackScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-announcements',
        icon: Icons.campaign_outlined,
        title: 'Announcements',
        subtitle: 'Post news for all members, search past posts',
        builder: (_) =>
            AdminAnnouncementsScreen(adminId: adminId, repository: _admin),
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
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: s.builder)),
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
  });

  final String key;

  /// Shows the number of reports no admin has seen yet.
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
  String get _statusLabel => _filters.firstWhere((f) => f.$2 == _status).$1;
  String _category = kAllFilter;
  String _period = kAllTime;
  final _search = TextEditingController();
  final _categoryText = TextEditingController(text: kAllFilter);
  late Future<List<Business>> _future;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _future = widget.repository.businesses(widget.adminId, status: _status);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _categoryText.dispose();
    super.dispose();
  }

  /// Search is on the list already loaded for the chosen status: name, owner,
  /// description and both links. Category and post date narrow it further.
  List<Business> _visible(List<Business> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((b) {
      if (_category != kAllFilter && b.category != _category) return false;
      if (!inPeriod(b.createdAt, _period)) return false;
      if (q.isEmpty) return true;
      return [
        b.name,
        b.ownerName,
        b.description,
        b.socialLink,
        b.websiteLink,
      ].any((v) => (v ?? '').toLowerCase().contains(q));
    }).toList();
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        key: const Key('admin-business-search'),
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Search name, owner or link...',
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
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: KeyedSubtree(
                        key: const Key('admin-business-status'),
                        child: FilterDropdown(
                          label: 'Status',
                          value: _statusLabel,
                          options: [for (final f in _filters) f.$1],
                          onChanged: (v) {
                            _status = _filters.firstWhere((f) => f.$1 == v).$2;
                            _reload();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SearchableChoice(
                        fieldKey: const Key('admin-business-category'),
                        label: 'Category',
                        controller: _categoryText,
                        options: [
                          kAllFilter,
                          ...CategoryRepository.shared.names.value,
                        ],
                        selected: _category,
                        enabled: true,
                        dense: true,
                        onSelected: (v) =>
                            setState(() => _category = v ?? kAllFilter),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: KeyedSubtree(
                        key: const Key('admin-business-period'),
                        child: FilterDropdown(
                          label: 'Posted',
                          value: _period,
                          options: kPeriodOptions,
                          onChanged: (v) => setState(() => _period = v),
                        ),
                      ),
                    ),
                  ],
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
                final all = snap.data ?? const <Business>[];
                if (all.isEmpty) {
                  return const Center(child: Text('Nothing here.'));
                }
                final items = _visible(all);
                if (items.isEmpty) {
                  return const Center(child: Text('Nothing matches.'));
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
            BusinessPhoto(url: b.photoUrl),
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
