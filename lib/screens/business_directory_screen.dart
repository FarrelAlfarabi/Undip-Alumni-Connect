import '../nav/back_guard.dart';

import 'package:flutter/material.dart';

import '../data/stale_cache.dart';
import '../widgets/responsive_list.dart';
import '../util/app_language.dart';

import '../data/block_list.dart';
import '../data/business_repository.dart';
import '../data/category_repository.dart';
import '../data/report_repository.dart';
import '../models/business.dart';
import '../util/friendly_error.dart';
import '../widgets/content_actions_menu.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/safe_link_chip.dart';
import '../widgets/searchable_choice.dart';
import 'business_form_screen.dart';
import 'marketplace_screen.dart' show ListingImage;
import 'my_businesses_screen.dart';
import '../widgets/app_photo.dart';
import '../widgets/error_view.dart';
import '../widgets/verified_badge.dart';
import '../lock/masking.dart' show initialsOf;

/// Client-side search by name or category, plus category and size filters.
/// [size] is a [BusinessBand.sizeLabel] (Mikro, Kecil, ...) or [kAllFilter];
/// the size is the band the admin approved.
List<Business> applyBusinessFilters(
  List<Business> all, {
  required String query,
  required String category,
  String size = kAllFilter,
}) {
  final q = query.trim().toLowerCase();
  return all.where((b) {
    if (category != kAllFilter && b.category != category) return false;
    if (size != kAllFilter && b.approvedBand?.sizeLabel != size) return false;
    if (q.isNotEmpty &&
        !b.name.toLowerCase().contains(q) &&
        !b.category.toLowerCase().contains(q)) {
      return false;
    }
    return true;
  }).toList();
}

/// Approved businesses, visible to verified alumni. This is the Businesses
/// list (reached from Home now, and from the Market tab later).
class BusinessDirectoryScreen extends StatefulWidget {
  const BusinessDirectoryScreen({
    super.key,
    required this.currentUser,
    this.repository,
    this.showBack = true,
    this.embedded = false,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;
  final BusinessRepository? repository;
  final bool showBack;

  /// True when shown inside another screen (no own AppBar).
  final bool embedded;

  @override
  State<BusinessDirectoryScreen> createState() =>
      _BusinessDirectoryScreenState();
}

class _BusinessDirectoryScreenState extends State<BusinessDirectoryScreen> {
  late final BusinessRepository _repo =
      widget.repository ?? BusinessRepository();
  final _search = TextEditingController();
  late Future<List<Business>> _future;
  final _categoryText = TextEditingController(text: tr(kAllFilter));
  String _category = kAllFilter;
  String _size = kAllFilter;

  String get _myId => widget.currentUser.value['id'] as String;

  String get _cacheKey => 'businesses:$_myId';

  Future<List<Business>> _fetchBusinesses() =>
      StaleCache.remember(_cacheKey, _repo.directory(_myId));

  late final SearchDebounce _searchDebounce;

  @override
  void initState() {
    super.initState();
    _future = _fetchBusinesses();
    _searchDebounce = SearchDebounce(_search, () {
      if (mounted) setState(() {});
    });
    CategoryRepository.shared.load();
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _search.dispose();
    _categoryText.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _future = _fetchBusinesses();
  });

  Future<void> _register() async {
    await Navigator.of(context).push<Business>(
      AppRoute(
        builder: (_) => BusinessFormScreen(ownerId: _myId, repository: _repo),
      ),
    );
  }

  Future<void> _openMine() async {
    await Navigator.of(context).push(
      AppRoute(
        builder: (_) => MyBusinessesScreen(ownerId: _myId, repository: _repo),
      ),
    );
    if (mounted) _reload();
  }

  Widget _mineButton() {
    // On very narrow phones the label would squeeze Kategori, so show only
    // the icon (with a tooltip) there.
    if (MediaQuery.sizeOf(context).width < 360) {
      return IconButton(
        key: const Key('my-businesses'),
        onPressed: _openMine,
        icon: const Icon(Icons.storefront_outlined),
        tooltip: tr('My businesses'),
      );
    }
    return TextButton.icon(
      key: const Key('my-businesses'),
      onPressed: _openMine,
      icon: const Icon(Icons.storefront_outlined, size: 18),
      label: Text(tr('My businesses')),
    );
  }

  Widget _body() {
    return FutureBuilder<List<Business>>(
      future: _future,
      initialData: StaleCache.peek<List<Business>>(_cacheKey),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(
            message: friendlyLoadError('the business directory', snap.error),
            screen: 'Businesses',
            error: snap.error,
            onRetry: _reload,
          );
        }
        final all = BlockList.shared.filter(
          snap.data ?? const <Business>[],
          (b) => b.ownerId,
        );
        if (all.isEmpty) {
          final empty = Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                tr(
                  'No businesses yet. Approved businesses run by alumni will '
                  'show up here.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
          if (!widget.embedded) return empty;
          // Keep "My businesses" reachable when the list is empty.
          return Column(
            children: [
              Align(alignment: Alignment.centerRight, child: _mineButton()),
              Expanded(child: empty),
            ],
          );
        }
        final items = applyBusinessFilters(
          all,
          query: _search.text,
          category: _category,
          size: _size,
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ClearableSearchField(
                controller: _search,
                hintText: tr('Search by name or category...'),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, widget.embedded ? 8 : 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<List<String>>(
                      valueListenable: CategoryRepository.shared.names,
                      builder: (context, names, _) => SearchableChoice(
                        fieldKey: const Key('business-category'),
                        label: tr('Kategori'),
                        controller: _categoryText,
                        options: [kAllFilter, ...names],
                        selected: _category,
                        enabled: true,
                        onSelected: (v) =>
                            setState(() => _category = v ?? kAllFilter),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: KeyedSubtree(
                      key: const Key('business-size-filter'),
                      child: FilterDropdown(
                        label: tr('Ukuran usaha'),
                        value: _size,
                        options: [kAllFilter, ...BusinessBand.sizeOptions],
                        onChanged: (v) => setState(() => _size = v),
                      ),
                    ),
                  ),
                  if (widget.embedded) _mineButton(),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(tr('No businesses match this search.')))
                  : RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        try {
                          await _future;
                        } catch (_) {}
                      },
                      child: ResponsiveListView(
                        minTileWidth: 300,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _BusinessCard(
                          business: items[i],
                          onTap: () => Navigator.of(context).push(
                            AppRoute(
                              builder: (_) => BusinessDetailScreen(
                                business: items[i],
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.extended(
      onPressed: _register,
      icon: const Icon(Icons.add_business_outlined),
      label: Text(tr('Register a business')),
    );
    if (widget.embedded) {
      return Scaffold(floatingActionButton: fab, body: _body());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Businesses')),
        automaticallyImplyLeading: widget.showBack,
        actions: [
          IconButton(
            onPressed: _openMine,
            icon: const Icon(Icons.storefront_outlined),
            tooltip: tr('My businesses'),
          ),
        ],
      ),
      floatingActionButton: fab,
      body: _body(),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business, required this.onTap});

  final Business business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Same layout as the Marketplace list card: square photo on the left,
    // title and details on the right.
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
              url: business.photoUrl ?? '',
              size: 104,
              semanticLabel: trf('Photo of {0}', [business.name]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NameWithBadge(
                      name: business.name,
                      verified: business.nibVerified,
                      maxLines: 2,
                      badgeSize: 16,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        business.category,
                        if (business.ownerName != null)
                          'by ${business.ownerName}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (business.approvedBand != null) ...[
                      const SizedBox(height: 6),
                      BusinessSizeChip(
                        key: Key('business-size-${business.id}'),
                        band: business.approvedBand!,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      business.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
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

/// One approved business, with its links.
class BusinessDetailScreen extends StatelessWidget {
  const BusinessDetailScreen({
    super.key,
    required this.business,
    required this.currentUser,
  });

  final Business business;
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = business;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business'),
        actions: [
          ContentActionsMenu(
            currentUserId: currentUser.value['id'] as String,
            ownerId: b.ownerId,
            ownerName: b.ownerName,
            reportType: ReportTarget.business,
            targetId: b.id,
            what: 'usaha ini',
            onBlocked: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BusinessDetailPhoto(url: b.photoUrl, name: b.name),
                  const SizedBox(height: 20),
                  NameWithBadge(
                    name: b.name,
                    verified: b.nibVerified,
                    badgeSize: 24,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      b.category,
                      if (b.ownerName != null) 'by ${b.ownerName}',
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (b.approvedBand != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BusinessSizeChip(band: b.approvedBand!),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(b.description, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (b.socialLink != null)
                        SafeLinkChip(
                          icon: Icons.alternate_email,
                          label: tr('Instagram / social'),
                          url: b.socialLink!,
                        ),
                      if (b.websiteLink != null)
                        SafeLinkChip(
                          icon: Icons.language,
                          label: 'Website',
                          url: b.websiteLink!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The business size as a small pill: "Mikro", "Kecil", ...
class BusinessSizeChip extends StatelessWidget {
  const BusinessSizeChip({super.key, required this.band});

  final BusinessBand band;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: trf('Ukuran: {0}', [band.sizeLabel]),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            band.sizeLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Large square business photo for the detail page. Falls back to the
/// business initials on a soft square when there is no photo.
class _BusinessDetailPhoto extends StatelessWidget {
  const _BusinessDetailPhoto({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u != null && u.isNotEmpty) {
      return AppPhoto(url: u, aspectRatio: 1, radius: 16, semanticLabel: name);
    }
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          key: const ValueKey('business-initials'),
          color: scheme.secondaryContainer,
          child: Center(
            child: Text(
              initialsOf(name),
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
