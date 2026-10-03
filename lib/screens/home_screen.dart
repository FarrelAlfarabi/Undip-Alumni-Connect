import 'package:flutter/material.dart';

import '../data/block_list.dart';
import '../data/home_repository.dart';
import '../data/marketplace_format.dart';
import '../data/marketplace_repository.dart';
import '../models/marketplace_listing.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/upcoming_section.dart';
import 'home_pages.dart';

/// First name for the greeting: the first word of `name`, or null.
String? firstNameOf(Map<String, dynamic> profile) {
  final name = (profile['name'] as String? ?? '').trim();
  if (name.isEmpty) return null;
  return name.split(RegExp(r'\s+')).first;
}

/// Dashboard home: greeting, announcement banners, quick-action tiles and a
/// "Latest" strip (jobs and marketplace listings). Uses only data that other
/// screens already read; nothing here gates or changes those screens.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.onOpenDirectory,
    this.pages = const HomePages(),
    this.api,
    this.marketplaceRepository,
    this.autoAdvance = const Duration(seconds: 5),
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// Switches the shell to the Directory tab (the Directory tile).
  final VoidCallback onOpenDirectory;

  final HomePages pages;

  /// Injectable for tests; default to the Supabase-backed versions.
  final HomeApi? api;
  final MarketplaceRepository? marketplaceRepository;

  final Duration autoAdvance;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeApi _api;
  late final MarketplaceRepository _market;
  late Future<List<Map<String, dynamic>>> _announcements;
  late Future<List<Map<String, dynamic>>> _jobs;
  late Future<List<MarketplaceListing>> _listings;
  late Future<int> _pendingRequests;
  late Future<int> _unreadNotifications;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? SupabaseHomeApi();
    _market = widget.marketplaceRepository ?? MarketplaceRepository();
    _load();
  }

  void _load() {
    _announcements = _api.latestAnnouncements(kHomeBannerLimit);
    _jobs = _latestJobs();
    _listings = _fetchListings();
    _pendingRequests = _api
        .pendingRequestCount(_user.value['id'] as String)
        .catchError((_) => 0);
    _unreadNotifications = _api
        .unreadNotificationCount(_user.value['id'] as String)
        .catchError((_) => 0);
  }

  Future<List<Map<String, dynamic>>> _latestJobs() async {
    final jobs = await _api.latestJobs(kHomeLatestLimit);
    await BlockList.shared.ensureLoaded();
    return BlockList.shared.filter(jobs, (j) => j['posted_by'] as String?);
  }

  Future<List<MarketplaceListing>> _fetchListings() async {
    final all = await _market.fetchApproved(); // already without blocked people
    final sorted = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(kHomeLatestLimit).toList();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([
      _announcements.catchError((_) => <Map<String, dynamic>>[]),
      _jobs.catchError((_) => <Map<String, dynamic>>[]),
      _listings.catchError((_) => <MarketplaceListing>[]),
    ]);
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  ValueNotifier<Map<String, dynamic>> get _user => widget.currentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = firstNameOf(_user.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lingkaran'),
        automaticallyImplyLeading: false,
        actions: [
          FutureBuilder<int>(
            future: _unreadNotifications,
            builder: (context, snap) {
              final n = snap.data ?? 0;
              return IconButton(
                key: const Key('home-notifications'),
                tooltip: n > 0 ? 'Notifications ($n new)' : 'Notifications',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => widget.pages.notifications(_user),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      _unreadNotifications = _api
                          .unreadNotificationCount(_user.value['id'] as String)
                          .catchError((_) => 0);
                    });
                  }
                },
                icon: Badge(
                  key: const Key('notifications-badge'),
                  isLabelVisible: n > 0,
                  label: Text('$n'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
          FutureBuilder<int>(
            future: _pendingRequests,
            builder: (context, snap) {
              final n = snap.data ?? 0;
              return IconButton(
                key: const Key('home-requests'),
                tooltip: n > 0 ? 'Requests ($n waiting)' : 'Requests',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => widget.pages.requests(_user),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      _pendingRequests = _api
                          .pendingRequestCount(_user.value['id'] as String)
                          .catchError((_) => 0);
                    });
                  }
                },
                icon: Badge(
                  key: const Key('requests-badge'),
                  isLabelVisible: n > 0,
                  label: Text('$n'),
                  child: const Icon(Icons.handshake_outlined),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          // A short fixed set of sections, so a plain scroll view (built in
          // full) rather than a lazy ListView.
          child: SingleChildScrollView(
            key: const Key('home-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  first == null ? 'Hello' : 'Hello, $first',
                  key: const Key('home-greeting'),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'What would you like to do today?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _bannerSection(theme),
                const SizedBox(height: 20),
                _QuickActions(
                  onJobs: () => _push(widget.pages.jobs(_user)),
                  onMarketplace: () => _push(widget.pages.marketplace(_user)),
                  onBusinesses: () => _push(widget.pages.businesses(_user)),
                  onDirectory: widget.onOpenDirectory,
                  onNearby: () => _push(widget.pages.nearby(_user)),
                ),
                const SizedBox(height: 24),
                _sectionTitle(theme, 'Latest'),
                const SizedBox(height: 8),
                _LatestBlock<Map<String, dynamic>>(
                  key: const Key('latest-jobs'),
                  heading: 'New jobs',
                  future: _jobs,
                  emptyIcon: Icons.work_outline,
                  emptyText:
                      'No jobs posted yet. New openings will show up here.',
                  onRetry: () => setState(() {
                    _jobs = _latestJobs();
                  }),
                  tileBuilder: (job) => _LatestTile(
                    icon: Icons.work_outline,
                    title: job['title'] as String? ?? '',
                    subtitle: [
                      job['company'] as String? ?? '',
                      if ((job['industry'] as String?)?.isNotEmpty == true)
                        job['industry'] as String,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    onTap: () => _push(widget.pages.jobDetail(job, _user)),
                  ),
                ),
                const SizedBox(height: 12),
                _LatestBlock<MarketplaceListing>(
                  key: const Key('latest-listings'),
                  heading: 'New in the marketplace',
                  future: _listings,
                  emptyIcon: Icons.storefront_outlined,
                  emptyText:
                      'No listings yet. Approved listings will show up here.',
                  onRetry: () => setState(() {
                    _listings = _fetchListings();
                  }),
                  tileBuilder: (l) => _LatestTile(
                    icon: Icons.storefront_outlined,
                    title: l.title,
                    subtitle:
                        '${l.category} · ${l.city} · ${formatRupiah(l.priceIdr)}',
                    onTap: () =>
                        _push(widget.pages.listingDetail(l, _market, _user)),
                  ),
                ),
                const SizedBox(height: 24),
                const UpcomingSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) => Text(
    text,
    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  );

  Widget _bannerSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _announcements,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Container(
                key: const Key('banner-loading'),
                height: 172,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const CircularProgressIndicator(),
              );
            }
            if (snap.hasError) {
              return _MessageCard(
                key: const Key('banner-error'),
                icon: Icons.cloud_off_outlined,
                text: "Couldn't load announcements.",
                actionLabel: 'Try again',
                onAction: () => setState(() {
                  _announcements = _api.latestAnnouncements(kHomeBannerLimit);
                }),
              );
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) return const WelcomeBannerCard();
            return BannerCarousel(
              items: items,
              autoAdvance: widget.autoAdvance,
              onOpen: (a) => _push(widget.pages.announcementDetail(a)),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('see-all-announcements'),
            onPressed: () => _push(widget.pages.announcements()),
            child: const Text('See all announcements'),
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onJobs,
    required this.onMarketplace,
    required this.onBusinesses,
    required this.onDirectory,
    required this.onNearby,
  });

  final VoidCallback onJobs;
  final VoidCallback onMarketplace;
  final VoidCallback onBusinesses;
  final VoidCallback onDirectory;
  final VoidCallback onNearby;

  @override
  Widget build(BuildContext context) {
    // Fixed tile height (not an aspect ratio) so tiles don't balloon on wide
    // screens; four across on desktop-width layouts.
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 4 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 64,
      ),
      children: [
        _Tile(
          key: const Key('tile-jobs'),
          icon: Icons.work_outline,
          label: 'Jobs',
          onTap: onJobs,
        ),
        _Tile(
          key: const Key('tile-marketplace'),
          icon: Icons.storefront_outlined,
          label: 'Marketplace',
          onTap: onMarketplace,
        ),
        _Tile(
          key: const Key('tile-businesses'),
          icon: Icons.business_center_outlined,
          label: 'Businesses',
          onTap: onBusinesses,
        ),
        _Tile(
          key: const Key('tile-directory'),
          icon: Icons.people_outline,
          label: 'Directory',
          onTap: onDirectory,
        ),
        _Tile(
          key: const Key('tile-nearby'),
          icon: Icons.near_me_outlined,
          label: 'Nearby Alumni',
          onTap: onNearby,
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestBlock<T> extends StatelessWidget {
  const _LatestBlock({
    super.key,
    required this.heading,
    required this.future,
    required this.tileBuilder,
    required this.emptyIcon,
    required this.emptyText,
    required this.onRetry,
  });

  final String heading;
  final Future<List<T>> future;
  final Widget Function(T item) tileBuilder;
  final IconData emptyIcon;
  final String emptyText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          heading,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        FutureBuilder<List<T>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return _MessageCard(
                icon: Icons.cloud_off_outlined,
                text: "Couldn't load this right now.",
                actionLabel: 'Try again',
                onAction: onRetry,
              );
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return _MessageCard(icon: emptyIcon, text: emptyText);
            }
            return Column(
              children: [
                for (final item in items) ...[
                  tileBuilder(item),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LatestTile extends StatelessWidget {
  const _LatestTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
