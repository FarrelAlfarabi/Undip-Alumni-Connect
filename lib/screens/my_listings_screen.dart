import 'package:flutter/material.dart';

import '../data/marketplace_format.dart';
import '../data/marketplace_image_picker.dart';
import '../data/marketplace_messages.dart';
import '../data/marketplace_repository.dart';
import '../models/marketplace_listing.dart';
import '../widgets/marketplace_demo_notice.dart';
import 'marketplace_form_screen.dart';
import 'marketplace_screen.dart' show ListingImage;
import '../widgets/error_view.dart';

/// The seller's own listings in every status, with edit / mark as sold /
/// delete.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({
    super.key,
    required this.sellerId,
    required this.repository,
    this.defaultCity,
    this.pickImage = pickListingImage,
  });

  final String sellerId;
  final MarketplaceRepository repository;
  final String? defaultCity;
  final ImagePickerFn pickImage;

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  late Future<List<MarketplaceListing>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchMine(widget.sellerId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.fetchMine(widget.sellerId);
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  void _toastError(Object e) => showErrorSnackBar(
    context,
    message: marketplaceErrorMessage(e),
    screen: 'My listings',
    error: e,
  );

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _edit(MarketplaceListing l) async {
    final saved = await Navigator.of(context).push<MarketplaceListing>(
      MaterialPageRoute(
        builder: (_) => MarketplaceFormScreen(
          sellerId: widget.sellerId,
          repository: widget.repository,
          existing: l,
          defaultCity: widget.defaultCity,
          pickImage: widget.pickImage,
        ),
      ),
    );
    if (saved != null && mounted) _reload();
  }

  Future<void> _markSold(MarketplaceListing l) async {
    final ok = await _confirm(
      title: 'Mark as sold?',
      body: 'It will disappear from the marketplace. This cannot be undone.',
      action: 'Mark as sold',
    );
    if (!ok) return;
    try {
      await widget.repository.markSold(widget.sellerId, l.id);
      if (!mounted) return;
      _toast('Marked as sold.');
      _reload();
    } catch (e) {
      if (mounted) _toastError(e);
    }
  }

  Future<void> _delete(MarketplaceListing l) async {
    final ok = await _confirm(
      title: 'Delete this listing?',
      body: '"${l.title}" will be removed for good.',
      action: 'Delete',
    );
    if (!ok) return;
    try {
      await widget.repository.delete(widget.sellerId, l.id);
      if (!mounted) return;
      _toast('Listing deleted.');
      _reload();
    } catch (e) {
      if (mounted) _toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      body: Column(
        children: [
          const MarketplaceDemoNotice(),
          Expanded(
            child: FutureBuilder<List<MarketplaceListing>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: 'Could not load your listings. Try again.',
                    screen: 'My listings',
                    error: snapshot.error,
                    onRetry: _reload,
                    retryLabel: 'Retry',
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'You have no listings yet. Use "Add a product" on '
                        'the marketplace to add one.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _MyListingCard(
                    listing: items[i],
                    onEdit: () => _edit(items[i]),
                    onSold: () => _markSold(items[i]),
                    onDelete: () => _delete(items[i]),
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

class _MyListingCard extends StatelessWidget {
  const _MyListingCard({
    required this.listing,
    required this.onEdit,
    required this.onSold,
    required this.onDelete,
  });

  final MarketplaceListing listing;
  final VoidCallback onEdit;
  final VoidCallback onSold;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = listing;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
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
                      const SizedBox(height: 2),
                      Text(
                        formatRupiah(l.priceIdr),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(status: l.status),
                    ],
                  ),
                ),
              ],
            ),
            if (l.isHidden) ...[
              const SizedBox(height: 8),
              Text(
                'Hidden by an admin${l.hiddenReason != null ? ': ${l.hiddenReason}' : ''}. '
                'Other people cannot see this product.',
                key: Key('hidden-${l.id}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (l.status == ListingStatus.rejected) ...[
              const SizedBox(height: 8),
              Text(
                'Rejected: ${l.rejectedReason ?? 'No reason given'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              Text(
                'Edit and save to send it for review again.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (l.status != ListingStatus.sold)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                if (l.status == ListingStatus.approved)
                  TextButton.icon(
                    onPressed: onSold,
                    icon: const Icon(Icons.sell_outlined, size: 18),
                    label: const Text('Mark as sold'),
                  ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      ListingStatus.pending => (
        'Pending review',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ListingStatus.approved => (
        'Approved',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      ListingStatus.rejected => (
        'Rejected',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      ListingStatus.sold => (
        'Sold',
        scheme.surfaceContainerHigh,
        scheme.onSurface,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
