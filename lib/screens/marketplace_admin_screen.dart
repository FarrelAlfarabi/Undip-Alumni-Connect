import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../data/marketplace_format.dart';
import '../data/marketplace_messages.dart';
import '../data/marketplace_repository.dart';
import '../models/marketplace_listing.dart';
import '../widgets/marketplace_demo_notice.dart';
import 'marketplace_screen.dart' show ListingImage;
import '../widgets/error_view.dart';
import '../widgets/undo_snackbar.dart';

/// Admin: review queue for pending listings (the old seed listings), plus
/// report counts per listing. Reached from Profile > Admin, which shows only
/// when the database says this profile is in app_admins. The database checks
/// the admin id again on every call.
class MarketplaceAdminScreen extends StatelessWidget {
  const MarketplaceAdminScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final MarketplaceRepository repository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Marketplace review')),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Review queue'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: Column(
          children: [
            const MarketplaceDemoNotice(),
            Expanded(
              child: TabBarView(
                children: [
                  _ReviewQueue(adminId: adminId, repository: repository),
                  _ReportsTab(adminId: adminId, repository: repository),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewQueue extends StatefulWidget {
  const _ReviewQueue({required this.adminId, required this.repository});

  final String adminId;
  final MarketplaceRepository repository;

  @override
  State<_ReviewQueue> createState() => _ReviewQueueState();
}

class _ReviewQueueState extends State<_ReviewQueue> {
  late Future<List<MarketplaceListing>> _future;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchPending(widget.adminId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.fetchPending(widget.adminId);
    });
  }

  Future<void> _decide(MarketplaceListing l, {required bool approve}) async {
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (reason == null) return;
    }
    setState(() => _busy.add(l.id));
    try {
      await widget.repository.review(
        adminId: widget.adminId,
        listingId: l.id,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      _busy.remove(l.id);
      showUndoSnackBar(
        context,
        message: approve
            ? 'Disetujui: "${l.title}".'
            : 'Ditolak: "${l.title}".',
        screen: 'Marketplace review',
        errorText: marketplaceErrorMessage,
        onUndo: () async {
          await widget.repository.unreview(
            adminId: widget.adminId,
            listingId: l.id,
          );
          if (mounted) _reload();
        },
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(l.id));
      showErrorSnackBar(
        context,
        message: marketplaceErrorMessage(e),
        screen: 'Marketplace review',
        error: e,
      );
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(tr('Reject listing')),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('Reason (shown to the seller)'),
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
                  if (t.isEmpty) {
                    setLocal(() => error = 'A reason is required');
                    return;
                  }
                  Navigator.of(ctx).pop(t);
                },
                child: Text(tr('Reject')),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MarketplaceListing>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorRetry(
            text: marketplaceErrorMessage(snapshot.error!),
            onRetry: _reload,
            screen: 'Marketplace review',
            error: snapshot.error,
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(child: Text(tr('Nothing waiting for review.')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final l = items[i];
            final busy = _busy.contains(l.id);
            final theme = Theme.of(context);
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ListingImage(
                            url: l.imageUrl,
                            size: 72,
                            semanticLabel: 'Photo of ${l.title}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                priceLabel(l.priceIdr, l.priceNegotiable),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                [
                                  l.category,
                                  if (l.city.isNotEmpty) l.city,
                                ].join(' · '),
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                'By ${l.seller?.name ?? 'Alumni'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((l.shopUrl ?? '').isNotEmpty)
                      Text(
                        'Shop: ${l.shopUrl}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if ((l.contactInfo ?? '').isNotEmpty)
                      Text(
                        'Contact: ${l.contactInfo}',
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _decide(l, approve: false),
                            child: Text(tr('Reject')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: busy
                                ? null
                                : () => _decide(l, approve: true),
                            child: Text(tr('Approve')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab({required this.adminId, required this.repository});

  final String adminId;
  final MarketplaceRepository repository;

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  late Future<List<ReportDetail>> _future;
  bool _dismissed = false;
  final _busy = <String>{};

  MarketplaceRepository get _repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ReportDetail>> _load() =>
      _repo.fetchReportDetails(widget.adminId, dismissed: _dismissed);

  void _reload() => setState(() {
    _future = _load();
  });

  String _reasonLabel(String name) {
    for (final r in ReportReason.values) {
      if (r.name == name) return r.label;
    }
    return name;
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(tr('Sembunyikan produk ini?')),
            content: TextField(
              key: const Key('product-hide-reason'),
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: tr('Alasan (dikirim ke pemilik)'),
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                key: const Key('product-hide-confirm'),
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) {
                    setLocal(() => error = 'Alasan wajib diisi');
                    return;
                  }
                  Navigator.of(ctx).pop(t);
                },
                child: const Text('Sembunyikan'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _run(
    ReportDetail d,
    Future<void> Function() action,
    String done,
    Future<void> Function() undo,
  ) async {
    setState(() => _busy.add(d.listingId));
    try {
      await action();
      if (!mounted) return;
      showUndoSnackBar(
        context,
        message: done,
        screen: 'Marketplace reports',
        errorText: marketplaceErrorMessage,
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
          message: marketplaceErrorMessage(e),
          screen: 'Marketplace reports',
          error: e,
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(d.listingId));
    }
  }

  Future<void> _dismiss(ReportDetail d) => _run(
    d,
    () => _repo.setReportsDismissed(
      adminId: widget.adminId,
      listingId: d.listingId,
      dismissed: true,
    ),
    'Laporan diabaikan.',
    () => _repo.setReportsDismissed(
      adminId: widget.adminId,
      listingId: d.listingId,
      dismissed: false,
    ),
  );

  Future<void> _reopen(ReportDetail d) => _run(
    d,
    () => _repo.setReportsDismissed(
      adminId: widget.adminId,
      listingId: d.listingId,
      dismissed: false,
    ),
    'Laporan dibuka lagi.',
    () => _repo.setReportsDismissed(
      adminId: widget.adminId,
      listingId: d.listingId,
      dismissed: true,
    ),
  );

  Future<void> _hide(ReportDetail d) async {
    final reason = await _askReason();
    if (reason == null || !mounted) return;
    await _run(
      d,
      () => _repo.setListingHidden(
        adminId: widget.adminId,
        listingId: d.listingId,
        hidden: true,
        reason: reason,
      ),
      'Produk disembunyikan. Pemilik diberi tahu.',
      () => _repo.setListingHidden(
        adminId: widget.adminId,
        listingId: d.listingId,
        hidden: false,
      ),
    );
  }

  Future<void> _show(ReportDetail d) => _run(
    d,
    () => _repo.setListingHidden(
      adminId: widget.adminId,
      listingId: d.listingId,
      hidden: false,
    ),
    'Produk ditampilkan lagi.',
    () => _repo.setListingHidden(
      adminId: widget.adminId,
      listingId: d.listingId,
      hidden: true,
      reason: d.hiddenReason ?? 'Disembunyikan oleh admin',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FilterChip(
              key: const Key('reports-show-dismissed'),
              label: Text(tr('Tampilkan yang diabaikan')),
              selected: _dismissed,
              onSelected: (v) {
                _dismissed = v;
                _reload();
              },
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ReportDetail>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErrorRetry(
                  text: marketplaceErrorMessage(snapshot.error!),
                  onRetry: _reload,
                  screen: 'Marketplace review',
                  error: snapshot.error,
                );
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    _dismissed
                        ? 'Belum ada laporan yang diabaikan.'
                        : 'Belum ada laporan.',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final d = rows[i];
                  final busy = _busy.contains(d.listingId);
                  return Card(
                    key: Key('report-${d.listingId}'),
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
                                  d.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${d.count} ${d.count == 1 ? 'report' : 'reports'}',
                                style: theme.textTheme.labelLarge,
                              ),
                            ],
                          ),
                          Text(
                            'Penjual: ${d.sellerName ?? 'Alumni'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (var k = 0; k < d.reasons.length; k++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${k < d.reporters.length ? d.reporters[k] : 'Alumni'}: '
                                '${_reasonLabel(d.reasons[k])}'
                                '${k < d.notes.length && d.notes[k].isNotEmpty ? ' - ${d.notes[k]}' : ''}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          if (d.isHidden)
                            Text(
                              'Disembunyikan: ${d.hiddenReason ?? '-'}',
                              key: Key('report-hidden-${d.listingId}'),
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            children: [
                              if (_dismissed)
                                OutlinedButton(
                                  key: Key('report-reopen-${d.listingId}'),
                                  onPressed: busy ? null : () => _reopen(d),
                                  child: Text(tr('Buka lagi')),
                                )
                              else
                                OutlinedButton(
                                  key: Key('report-dismiss-${d.listingId}'),
                                  onPressed: busy ? null : () => _dismiss(d),
                                  child: Text(tr('Abaikan laporan')),
                                ),
                              if (d.isHidden)
                                FilledButton(
                                  key: Key('report-show-${d.listingId}'),
                                  onPressed: busy ? null : () => _show(d),
                                  child: Text(tr('Tampilkan lagi')),
                                )
                              else
                                FilledButton(
                                  key: Key('report-hide-${d.listingId}'),
                                  onPressed: busy ? null : () => _hide(d),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.error,
                                    foregroundColor: theme.colorScheme.onError,
                                  ),
                                  child: Text(tr('Sembunyikan produk')),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({
    required this.text,
    required this.onRetry,
    required this.screen,
    this.error,
  });

  final String text;
  final VoidCallback onRetry;
  final String screen;
  final Object? error;

  @override
  Widget build(BuildContext context) => ErrorView(
    message: text,
    screen: screen,
    error: error,
    onRetry: onRetry,
    retryLabel: 'Retry',
  );
}
