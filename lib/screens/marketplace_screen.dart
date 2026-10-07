import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../data/marketplace_format.dart';
import '../data/marketplace_image_picker.dart';
import '../data/marketplace_messages.dart';
import '../data/marketplace_repository.dart';
import '../models/business.dart';
import '../models/marketplace_listing.dart';
import '../util/friendly_error.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/marketplace_demo_notice.dart';
import 'business_form_screen.dart';
import 'marketplace_form_screen.dart';
import 'marketplace_detail_screen.dart';
import 'my_listings_screen.dart';
import '../widgets/error_view.dart';

enum MarketplaceSort {
  newest('Newest'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low');

  const MarketplaceSort(this.label);
  final String label;
}

/// Client-side search (title), category filter and sort, same approach as
/// the job board. Fine for a demo-sized list, not meant to scale.
List<MarketplaceListing> applyMarketplaceFilters(
  List<MarketplaceListing> all, {
  required String query,
  required String category,
  required MarketplaceSort sort,
}) {
  final q = query.trim().toLowerCase();
  final result = all.where((l) {
    if (category != kAllFilter && l.category != category) return false;
    if (q.isNotEmpty && !l.title.toLowerCase().contains(q)) return false;
    return true;
  }).toList();
  switch (sort) {
    case MarketplaceSort.newest:
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case MarketplaceSort.priceLow:
      result.sort((a, b) => a.priceIdr.compareTo(b.priceIdr));
    case MarketplaceSort.priceHigh:
      result.sort((a, b) => b.priceIdr.compareTo(a.priceIdr));
  }
  return result;
}

/// Alumni-to-alumni marketplace (demo): browse approved listings. Free for
/// everyone; adding a product needs an approved business (see [_post]).
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    super.key,
    required this.currentUser,
    this.repository,
    this.pickImage = pickListingImage,
    this.showBack = false,
    this.businessRepository,
    this.embedded = false,
  });

  /// True when shown inside the Market tab (no own app bar).
  final bool embedded;

  /// Injectable for tests.
  final BusinessRepository? businessRepository;

  /// True when pushed from the Home hub (shows a back arrow).
  final bool showBack;

  /// Injectable for tests; defaults to the file picker.
  final ImagePickerFn pickImage;

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// Injectable for tests; defaults to the Supabase-backed repository.
  final MarketplaceRepository? repository;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late final MarketplaceRepository _repo;
  late Future<List<MarketplaceListing>> _future;

  final _searchController = TextEditingController();
  String _category = kAllFilter;
  MarketplaceSort _sort = MarketplaceSort.newest;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MarketplaceRepository();
    _future = _repo.fetchApproved(limit: kMarketplaceMaxRows);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _repo.fetchApproved(limit: kMarketplaceMaxRows);
    });
  }

  bool get _hasActiveFilters =>
      _searchController.text.isNotEmpty ||
      _category != kAllFilter ||
      _sort != MarketplaceSort.newest;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _category = kAllFilter;
      _sort = MarketplaceSort.newest;
    });
  }

  String get _myId => widget.currentUser.value['id'] as String;

  late final BusinessRepository _bizRepo =
      widget.businessRepository ?? BusinessRepository();
  bool _checkingPost = false;

  Future<void> _info(
    String title,
    String body, {
    String? action,
    VoidCallback? onAction,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(action == null ? 'OK' : 'Not now'),
          ),
          if (action != null)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onAction?.call();
              },
              child: Text(action),
            ),
        ],
      ),
    );
  }

  Future<Business?> _pickBusiness(List<Business> approved) async {
    if (approved.length == 1) return approved.first;
    return showModalBottomSheet<Business>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Add a product to which business?'),
            ),
            for (final b in approved)
              ListTile(
                key: Key('pick-${b.id}'),
                title: Text(b.name),
                subtitle: Text(b.category),
                onTap: () => Navigator.of(ctx).pop(b),
              ),
          ],
        ),
      ),
    );
  }

  // Only owners of approved businesses can add products, up to the limit the
  // database reports. The database enforces both rules too.
  Future<void> _post() async {
    if (_checkingPost) return;
    setState(() => _checkingPost = true);
    List<Business> approved;
    Map<String, BusinessUsage> usage;
    try {
      final mine = await _bizRepo.mine(_myId);
      final u = await _bizRepo.usage(_myId);
      approved = mine.where((b) => b.isApproved).toList();
      usage = {for (final x in u) x.businessId: x};
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          message: friendlyError(e),
          screen: 'Marketplace',
          error: e,
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _checkingPost = false);
    }
    if (!mounted) return;

    if (approved.isEmpty) {
      await _info(
        'Add a product',
        kProductsNeedBusinessMessage,
        action: 'Register a business',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                BusinessFormScreen(ownerId: _myId, repository: _bizRepo),
          ),
        ),
      );
      return;
    }

    final business = await _pickBusiness(approved);
    if (business == null || !mounted) return;

    final u = usage[business.id];
    if (u != null && !u.canPost) {
      await _info(
        'Free limit reached',
        'You have used ${u.used} of ${u.freeLimit} free products for '
            '${business.name}.\n\n$kPostLimitMessage',
      );
      return;
    }

    await Navigator.of(context).push<MarketplaceListing>(
      MaterialPageRoute(
        builder: (_) => MarketplaceFormScreen(
          sellerId: _myId,
          businessId: business.id,
          repository: _repo,
          defaultCity: widget.currentUser.value['city'] as String?,
          pickImage: widget.pickImage,
        ),
      ),
    );
    // The product is approved at creation, so show it right away.
    if (mounted) _reload();
  }

  Future<void> _openMine() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyListingsScreen(
          sellerId: _myId,
          repository: _repo,
          defaultCity: widget.currentUser.value['city'] as String?,
          pickImage: widget.pickImage,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Marketplace'),
              automaticallyImplyLeading: widget.showBack,
              actions: [
                IconButton(
                  onPressed: _openMine,
                  icon: const Icon(Icons.inventory_2_outlined),
                  tooltip: 'My listings',
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _post,
        icon: const Icon(Icons.add),
        label: const Text('Add a product'),
      ),
      body: Column(
        children: [
          const MarketplaceDemoNotice(),
          if (widget.embedded)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('my-listings'),
                onPressed: _openMine,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('My listings'),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<MarketplaceListing>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message:
                        'Could not load the marketplace. Check your '
                        'connection and try again.',
                    screen: 'Marketplace',
                    error: snapshot.error,
                    onRetry: _reload,
                    retryLabel: 'Retry',
                  );
                }

                final all = snapshot.data ?? [];
                if (all.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No listings yet. Approved listings from other '
                        'alumni will show up here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final listings = applyMarketplaceFilters(
                  all,
                  query: _searchController.text,
                  category: _category,
                  sort: _sort,
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: ClearableSearchField(
                        controller: _searchController,
                        hintText: 'Search by title...',
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        children: [
                          for (final c in [
                            kAllFilter,
                            ...kMarketplaceCategories,
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: _category == c,
                                onSelected: (_) =>
                                    setState(() => _category = c),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: FilterDropdown(
                        label: 'Sort',
                        value: _sort.label,
                        options: [
                          for (final s in MarketplaceSort.values) s.label,
                        ],
                        onChanged: (v) => setState(
                          () => _sort = MarketplaceSort.values.firstWhere(
                            (s) => s.label == v,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: ClearFiltersButton(
                        active: _hasActiveFilters,
                        onPressed: _clearFilters,
                      ),
                    ),
                    Expanded(
                      child: listings.isEmpty
                          ? const Center(
                              child: Text('No listings match these filters.'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                              itemCount: listings.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) => _ListingCard(
                                listing: listings[i],
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MarketplaceDetailScreen(
                                        listing: listings[i],
                                        repository: _repo,
                                        currentUser: widget.currentUser,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.onTap});

  final MarketplaceListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListingImage(
              url: listing.imageUrl,
              size: 104,
              semanticLabel: 'Photo of ${listing.title}',
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(listing.priceIdr),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.category} · ${listing.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listing photo with a neutral placeholder while loading or on error
/// (e.g. offline, or a host that blocks cross-origin image requests).
class ListingImage extends StatelessWidget {
  const ListingImage({
    super.key,
    required this.url,
    this.size,
    this.aspectRatio,
    this.semanticLabel,
  });

  final String url;

  /// Text alternative for screen readers (the listing title). When null the
  /// image is treated as decorative.
  final String? semanticLabel;

  /// Square size; when null the image fills the width at [aspectRatio].
  final double? size;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget placeholder() => Container(
      color: theme.colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    // Decode at the size it is drawn, not at the photo's full resolution (up
    // to 2 MB on disk, many megabytes decoded). Big memory and scroll-jank
    // saving on the list, where the photo is a small thumbnail.
    Widget photo(double width) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: (width * dpr).round(),
        gaplessPlayback: true,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        errorBuilder: (_, _, _) => placeholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder(),
      );
    }

    if (url.isEmpty) {
      return size != null
          ? SizedBox(width: size, height: size, child: placeholder())
          : AspectRatio(
              aspectRatio: aspectRatio ?? 3 / 2,
              child: placeholder(),
            );
    }
    if (size != null) {
      return SizedBox(width: size, height: size, child: photo(size!));
    }
    return AspectRatio(
      aspectRatio: aspectRatio ?? 3 / 2,
      child: LayoutBuilder(
        builder: (context, constraints) =>
            photo(constraints.hasBoundedWidth ? constraints.maxWidth : 600),
      ),
    );
  }
}
