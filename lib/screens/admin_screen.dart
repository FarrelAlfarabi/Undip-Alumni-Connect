import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../data/admin_repository.dart';
import '../data/category_repository.dart';
import '../data/marketplace_repository.dart';
import '../models/business.dart';
import '../util/friendly_error.dart';
import '../util/period_filter.dart';
import 'admin_announcements_screen.dart';
import 'admin_home_order_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_ikafe_contacts_screen.dart';
import 'admin_jobs_screen.dart';
import 'admin_log_screen.dart';
import 'admin_reports_screen.dart';
import 'marketplace_admin_screen.dart';
import '../widgets/business_photo.dart';
import '../widgets/error_view.dart';
import '../widgets/verified_badge.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/searchable_choice.dart';
import '../widgets/undo_snackbar.dart';

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
  AdminCounts _counts = const AdminCounts();

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  /// The red tags. A failure just shows no tags.
  Future<void> _loadCounts() async {
    try {
      final c = await _admin.pendingCounts(widget.adminId);
      if (mounted) setState(() => _counts = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final adminId = widget.adminId;
    final sections = [
      ...widget.extraSections,
      AdminSection(
        key: 'admin-reports',
        badge: _counts.reports,
        icon: Icons.flag_outlined,
        title: tr('Reports'),
        subtitle: tr('Reported content: dismiss, hide, restore'),
        builder: (_) =>
            AdminReportsScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-feedback',
        badge: _counts.feedback,
        icon: Icons.feedback_outlined,
        title: tr('Feedback'),
        subtitle: tr('What testers sent from the Send feedback button'),
        builder: (_) =>
            AdminFeedbackScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-announcements',
        icon: Icons.campaign_outlined,
        title: tr('Announcements'),
        subtitle: tr('Post news for all members, search past posts'),
        builder: (_) =>
            AdminAnnouncementsScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-ikafe-contacts',
        icon: Icons.contact_phone_outlined,
        title: tr('Kontak Ikafe'),
        subtitle: tr('Edit the contacts and socials members see'),
        builder: (_) =>
            AdminIkafeContactsScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-businesses',
        badge: _counts.businesses,
        icon: Icons.business_center_outlined,
        title: tr('Businesses'),
        subtitle: tr(
          'Setujui, tolak, tangguhkan. Produk bisnis yang disetujui langsung tayang',
        ),
        builder: (_) =>
            AdminBusinessesScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-jobs',
        icon: Icons.work_outline,
        title: 'Jobs',
        subtitle: tr('Lihat semua lowongan, tangguhkan atau tampilkan lagi'),
        builder: (_) => AdminJobsScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-log',
        icon: Icons.history,
        title: tr('Riwayat'),
        subtitle: tr(
          'Siapa menyetujui, menolak, menyembunyikan atau menghapus apa',
        ),
        builder: (_) => AdminLogScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-home-order',
        icon: Icons.push_pin_outlined,
        title: tr('Home order'),
        subtitle: tr('Pilih produk dan lowongan yang tampil dulu di Home'),
        builder: (_) =>
            AdminHomeOrderScreen(adminId: adminId, repository: _admin),
      ),
      AdminSection(
        key: 'admin-marketplace',
        badge: _counts.listings,
        icon: Icons.storefront_outlined,
        title: tr('Marketplace review'),
        subtitle: tr('Old listings waiting for review, report counts'),
        builder: (_) =>
            MarketplaceAdminScreen(adminId: adminId, repository: _market),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('Admin'))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_counts.total > 0) _PendingBanner(counts: _counts),
            for (final s in sections)
              Card(
                key: Key(s.key),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(s.icon),
                  title: Text(s.title),
                  subtitle: Text(s.subtitle),
                  trailing: s.badge > 0
                      ? Badge(
                          key: Key('badge-${s.key}'),
                          label: Text('${s.badge}'),
                          child: const Icon(Icons.chevron_right),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context)
                        .push(MaterialPageRoute(builder: s.builder));
                    _loadCounts();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Top of the Admin home: one sentence saying what waits, split by type.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.counts});

  final AdminCounts counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = [
      if (counts.businesses > 0) '${counts.businesses} bisnis perlu disetujui',
      if (counts.listings > 0) '${counts.listings} produk lama perlu ditinjau',
      if (counts.reports > 0) '${counts.reports} laporan baru',
      if (counts.feedback > 0) '${counts.feedback} masukan baru',
    ];
    return Card(
      key: const Key('admin-pending-banner'),
      color: theme.colorScheme.errorContainer,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                trf('Menunggu kamu: {0}.', [parts.join(', ')]),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
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
    this.badge = 0,
  });

  final String key;

  /// Red number on the button when above zero: things waiting for an admin.
  final int badge;

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

  /// Runs one decision. [done] is the notification text; the Urungkan button
  /// next to it puts the business back to how it was.
  Future<void> _run(
    Business b,
    Future<Business> Function() action,
    String done,
  ) async {
    setState(() => _busy.add(b.id));
    try {
      await action();
      if (!mounted) return;
      _busy.remove(b.id);
      showUndoSnackBar(
        context,
        message: done,
        screen: 'Admin businesses',
        errorText: adminErrorMessage,
        onUndo: () async {
          await widget.repository.setBusinessState(widget.adminId, b);
          if (mounted) _reload();
        },
      );
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

  /// Marks the NIB as checked, or takes the mark away. Nothing else changes.
  Future<void> _toggleNib(Business b) async {
    final verify = !b.nibVerified;
    setState(() => _busy.add(b.id));
    try {
      await widget.repository.setNibVerified(widget.adminId, b.id, verify);
      if (!mounted) return;
      _busy.remove(b.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verify
                ? 'NIB ${b.name} ditandai terverifikasi.'
                : 'Verifikasi NIB ${b.name} dicabut.',
          ),
        ),
      );
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

  Future<void> _approve(Business b) => _run(
    b,
    () => widget.repository.approve(widget.adminId, b.id),
    'Disetujui: ${b.name}.',
  );

  Future<void> _reject(Business b) async {
    final reason = await _askReason(
      title: tr('Reject business'),
      label: tr('Reason (shown to the owner)'),
      required: true,
      action: 'Reject',
    );
    if (reason == null) return;
    await _run(
      b,
      () => widget.repository.reject(widget.adminId, b.id, reason),
      'Ditolak: ${b.name}.',
    );
  }

  Future<void> _suspend(Business b) async {
    final reason = await _askReason(
      title: tr('Suspend business'),
      label: tr('Reason (shown to the owner, optional)'),
      required: false,
      action: 'Suspend',
    );
    if (reason == null) return;
    await _run(
      b,
      () => widget.repository.suspend(widget.adminId, b.id, reason: reason),
      'Ditangguhkan: ${b.name}. Produknya disembunyikan.',
    );
  }

  Future<void> _restore(Business b) => _run(
    b,
    () => widget.repository.restore(widget.adminId, b.id),
    'Dipulihkan: ${b.name}.',
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
                child: Text(tr('Cancel')),
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
      appBar: AppBar(title: Text(tr('Businesses'))),
      body: SafeArea(
        top: false,
        child: Column(
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
                            hintText: tr('Search name, owner or link...'),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    tooltip: tr('Clear search'),
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
                              _status = _filters
                                  .firstWhere((f) => f.$1 == v)
                                  .$2;
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
                          label: tr('Category'),
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
                            label: tr('Posted'),
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
                    return Center(child: Text(tr('Nothing here.')));
                  }
                  final items = _visible(all);
                  if (items.isEmpty) {
                    return Center(child: Text(tr('Nothing matches.')));
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
                      onToggleNib: () => _toggleNib(items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
    required this.onToggleNib,
  });

  final Business business;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSuspend;
  final VoidCallback onRestore;
  final VoidCallback onToggleNib;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = business;
    final actions = <Widget>[
      if (b.status == BusinessStatus.pending) ...[
        OutlinedButton(
          key: Key('reject-${b.id}'),
          onPressed: busy ? null : onReject,
          child: Text(tr('Reject')),
        ),
        FilledButton(
          key: Key('approve-${b.id}'),
          onPressed: busy ? null : onApprove,
          child: Text(tr('Approve')),
        ),
      ],
      if (b.status == BusinessStatus.rejected)
        FilledButton(
          key: Key('approve-${b.id}'),
          onPressed: busy ? null : onApprove,
          child: Text(tr('Approve')),
        ),
      if (b.status == BusinessStatus.approved)
        OutlinedButton(
          key: Key('suspend-${b.id}'),
          onPressed: busy ? null : onSuspend,
          child: Text(tr('Suspend')),
        ),
      if (b.status == BusinessStatus.suspended)
        FilledButton(
          key: Key('restore-${b.id}'),
          onPressed: busy ? null : onRestore,
          child: Text(tr('Restore')),
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
            NameWithBadge(
              name: b.name,
              verified: b.nibVerified,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${b.category} · ${tr('by')} ${b.ownerName ?? 'Alumni'} · ${b.status.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(b.description),
            const SizedBox(height: 8),
            if (b.socialLink != null)
              Text(
                trf('Social: {0}', [b.socialLink]),
                style: theme.textTheme.bodySmall,
              ),
            if (b.websiteLink != null)
              Text(
                trf('Website: {0}', [b.websiteLink]),
                style: theme.textTheme.bodySmall,
              ),
            if (b.nib != null) ...[
              Text(
                trf('NIB: {0} ({1})', [
                  b.nib,
                  b.nibVerified ? tr('sudah dicek') : tr('belum dicek'),
                ]),
                key: Key('nib-text-${b.id}'),
                style: theme.textTheme.bodySmall,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: Key('nib-verify-${b.id}'),
                  onPressed: busy ? null : onToggleNib,
                  child: Text(
                    tr(
                      b.nibVerified
                          ? 'Cabut verifikasi NIB'
                          : 'Tandai NIB terverifikasi',
                    ),
                  ),
                ),
              ),
            ],
            Text(
              trf('Band chosen by owner: {0}{1}', [
                b.requestedBand?.label ?? '-',
                b.approvedBand != null
                    ? ' · ${tr('approved')}: ${b.approvedBand!.label}'
                    : '',
              ]),
              style: theme.textTheme.bodySmall,
            ),
            if (b.rejectionReason != null && b.rejectionReason!.isNotEmpty)
              Text(
                trf('Reason: {0}', [b.rejectionReason]),
                style: theme.textTheme.bodySmall,
              ),
            if (b.unlimitedUntil != null)
              Text(
                trf('Unlimited posting until {0} (set in the dashboard)', [
                  b.unlimitedUntil!.toIso8601String().substring(0, 10),
                ]),
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
