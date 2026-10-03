import 'package:flutter/material.dart';

import '../data/block_list.dart';
import '../data/business_repository.dart';
import '../data/report_repository.dart';
import '../models/business.dart';
import '../util/friendly_error.dart';
import '../widgets/content_actions_menu.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/safe_link_chip.dart';
import 'business_form_screen.dart';
import 'my_businesses_screen.dart';
import '../widgets/error_view.dart';

/// Client-side search by name or category, plus a category filter.
List<Business> applyBusinessFilters(
  List<Business> all, {
  required String query,
  required String category,
}) {
  final q = query.trim().toLowerCase();
  return all.where((b) {
    if (category != kAllFilter && b.category != category) return false;
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
  String _category = kAllFilter;

  String get _myId => widget.currentUser.value['id'] as String;

  @override
  void initState() {
    super.initState();
    _future = _repo.directory(_myId);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _future = _repo.directory(_myId);
  });

  Future<void> _register() async {
    await Navigator.of(context).push<Business>(
      MaterialPageRoute(
        builder: (_) => BusinessFormScreen(ownerId: _myId, repository: _repo),
      ),
    );
  }

  Future<void> _openMine() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyBusinessesScreen(ownerId: _myId, repository: _repo),
      ),
    );
    if (mounted) _reload();
  }

  Widget _body() {
    return FutureBuilder<List<Business>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No businesses yet. Approved businesses run by alumni will '
                'show up here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final items = applyBusinessFilters(
          all,
          query: _search.text,
          category: _category,
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ClearableSearchField(
                controller: _search,
                hintText: 'Search by name or category...',
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
                  for (final c in [kAllFilter, ...kBusinessCategories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('No businesses match this search.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _BusinessCard(
                        business: items[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BusinessDetailScreen(
                              business: items[i],
                              currentUser: widget.currentUser,
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
      label: const Text('Register a business'),
    );
    if (widget.embedded) {
      return Scaffold(floatingActionButton: fab, body: _body());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Businesses'),
        automaticallyImplyLeading: widget.showBack,
        actions: [
          IconButton(
            onPressed: _openMine,
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'My businesses',
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
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                business.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                [
                  business.category,
                  if (business.ownerName != null) 'by ${business.ownerName}',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                business.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
            what: 'this business',
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
                  Text(
                    b.name,
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
                          label: 'Instagram / social',
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
