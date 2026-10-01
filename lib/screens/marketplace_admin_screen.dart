import 'package:flutter/material.dart';

import '../data/marketplace_format.dart';
import '../data/marketplace_messages.dart';
import '../data/marketplace_repository.dart';
import '../models/marketplace_listing.dart';
import '../widgets/marketplace_demo_notice.dart';
import 'marketplace_screen.dart' show ListingImage;

/// Demo admin: review queue for pending listings, plus report counts per
/// listing. Only reachable when marketplace_admins contains the current
/// profile, and every action also needs the admin passphrase (the profile id
/// alone is public, see SECURITY_AUDIT.md SA-04). The passphrase is asked for
/// here, kept only in this screen's memory and never stored on the device.
class MarketplaceAdminScreen extends StatefulWidget {
  const MarketplaceAdminScreen({
    super.key,
    required this.adminId,
    required this.repository,
    this.adminKey,
  });

  final String adminId;
  final MarketplaceRepository repository;

  /// Pre-filled passphrase (tests). Normally null: the screen asks for it.
  final String? adminKey;

  @override
  State<MarketplaceAdminScreen> createState() => _MarketplaceAdminScreenState();
}

class _MarketplaceAdminScreenState extends State<MarketplaceAdminScreen> {
  String? _key;

  @override
  void initState() {
    super.initState();
    _key = widget.adminKey;
  }

  @override
  void dispose() {
    _key = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = _key;
    if (key == null) {
      return _AdminKeyGate(
        adminId: widget.adminId,
        repository: widget.repository,
        onUnlocked: (k) => setState(() => _key = k),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marketplace admin'),
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
                  _ReviewQueue(
                    adminId: widget.adminId,
                    adminKey: key,
                    repository: widget.repository,
                  ),
                  _ReportsTab(
                    adminId: widget.adminId,
                    adminKey: key,
                    repository: widget.repository,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for the admin passphrase and checks it with one real admin call.
class _AdminKeyGate extends StatefulWidget {
  const _AdminKeyGate({
    required this.adminId,
    required this.repository,
    required this.onUnlocked,
  });

  final String adminId;
  final MarketplaceRepository repository;
  final void Function(String key) onUnlocked;

  @override
  State<_AdminKeyGate> createState() => _AdminKeyGateState();
}

class _AdminKeyGateState extends State<_AdminKeyGate> {
  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final key = _controller.text;
    if (key.isEmpty) {
      setState(() => _error = 'Enter the admin passphrase.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await widget.repository.fetchPending(widget.adminId, key);
      if (!mounted) return;
      widget.onUnlocked(key);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = marketplaceErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace admin')),
      body: Column(
        children: [
          const MarketplaceDemoNotice(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Admin passphrase',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Admin actions need the passphrase, not just your '
                        'account. It is not saved on this device.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('admin-key-field'),
                        controller: _controller,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        enabled: !_checking,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Passphrase',
                          errorText: _error,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('admin-key-submit'),
                        onPressed: _checking ? null : _submit,
                        child: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Unlock'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewQueue extends StatefulWidget {
  const _ReviewQueue({
    required this.adminId,
    required this.adminKey,
    required this.repository,
  });

  final String adminId;
  final String adminKey;
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
    _future = widget.repository.fetchPending(widget.adminId, widget.adminKey);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.fetchPending(widget.adminId, widget.adminKey);
    });
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), duration: const Duration(seconds: 4)),
  );

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
        adminKey: widget.adminKey,
        listingId: l.id,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      _toast(approve ? 'Approved "${l.title}".' : 'Rejected "${l.title}".');
      _busy.remove(l.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(l.id));
      _toast(marketplaceErrorMessage(e));
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
            title: const Text('Reject listing'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason (shown to the seller)',
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
                child: const Text('Reject'),
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
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('Nothing waiting for review.'));
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
                          child: ListingImage(url: l.imageUrl, size: 72),
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
                                formatRupiah(l.priceIdr),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${l.category} · ${l.city}',
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
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: busy
                                ? null
                                : () => _decide(l, approve: true),
                            child: const Text('Approve'),
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
  const _ReportsTab({
    required this.adminId,
    required this.adminKey,
    required this.repository,
  });

  final String adminId;
  final String adminKey;
  final MarketplaceRepository repository;

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  late Future<List<(ReportCount, String?)>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Titles come from the public approved list; a reported listing that is
  // no longer approved shows as unavailable.
  Future<List<(ReportCount, String?)>> _load() async {
    final counts = await widget.repository.fetchReportCounts(
      widget.adminId,
      widget.adminKey,
    );
    if (counts.isEmpty) return [];
    final approved = await widget.repository.fetchApproved();
    final titles = {for (final l in approved) l.id: l.title};
    return [for (final c in counts) (c, titles[c.listingId])];
  }

  void _reload() => setState(() {
    _future = _load();
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<(ReportCount, String?)>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorRetry(
            text: marketplaceErrorMessage(snapshot.error!),
            onRetry: _reload,
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const Center(child: Text('No reports yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final (c, title) = rows[i];
            final theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? 'Listing no longer available',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          c.listingId,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${c.count} ${c.count == 1 ? 'report' : 'reports'}',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
