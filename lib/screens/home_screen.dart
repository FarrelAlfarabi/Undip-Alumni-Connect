import 'package:flutter/material.dart';

import '../data/block_list.dart';
import '../data/home_repository.dart';
import '../data/marketplace_format.dart';
import '../data/marketplace_repository.dart';
import '../data/posting_text.dart';
import '../models/business.dart';
import '../models/marketplace_listing.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/feedback_sheet.dart';
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
    this.onOpenMarket,
    this.pages = const HomePages(),
    this.api,
    this.marketplaceRepository,
    this.autoAdvance = const Duration(seconds: 5),
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// Switches the shell to the Directory tab (the Directory tile).
  final VoidCallback onOpenDirectory;

  /// Switches the shell to the Market tab: 0 Products, 1 Businesses. When
  /// null (tests) the tiles push the pages instead.
  final void Function(int segment)? onOpenMarket;

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
  late Future<_BusinessSummary> _business;

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
    _business = _loadBusiness();
  }

  Future<_BusinessSummary> _loadBusiness() async {
    final id = _user.value['id'] as String;
    final mine = await _api.myBusinesses(id);
    final usage = await _api
        .myBusinessUsage(id)
        .catchError((_) => <BusinessUsage>[]);
    return _BusinessSummary(mine, {for (final u in usage) u.businessId: u});
  }

  Future<List<Map<String, dynamic>>> _latestJobs() async {
    final jobs = await _api.latestJobs(kHomeLatestLimit);
    await BlockList.shared.ensureLoaded();
    return BlockList.shared.filter(jobs, (j) => j['posted_by'] as String?);
  }

  Future<List<MarketplaceListing>> _fetchListings() async {
    final all = await _market.fetchApproved(
      limit: kHomeListingFetchLimit,
    ); // already without blocked people
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

  Future<void> _pushThenRefresh(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      setState(() {
        _business = _loadBusiness();
      });
    }
  }

  ValueNotifier<Map<String, dynamic>> get _user => widget.currentUser;

  Future<void> _openRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => widget.pages.requests(_user)),
    );
    if (mounted) {
      setState(() {
        _pendingRequests = _api
            .pendingRequestCount(_user.value['id'] as String)
            .catchError((_) => 0);
      });
    }
  }

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
                tooltip: n > 0 ? 'Notifikasi ($n baru)' : 'Notifikasi',
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
                tooltip: n > 0 ? 'Permintaan ($n menunggu)' : 'Permintaan',
                onPressed: _openRequests,
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
                  first == null ? 'Halo' : 'Halo, $first',
                  key: const Key('home-greeting'),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Apa yang ingin kamu lakukan hari ini?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<int>(
                  future: _pendingRequests,
                  builder: (context, snap) {
                    final n = snap.data ?? 0;
                    if (n <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RequestsCard(count: n, onTap: _openRequests),
                    );
                  },
                ),
                _bannerSection(theme),
                const SizedBox(height: 8),
                _QuickActions(
                  onJobs: () => _push(widget.pages.jobs(_user)),
                  onMarketplace: () => widget.onOpenMarket != null
                      ? widget.onOpenMarket!(0)
                      : _push(widget.pages.marketplace(_user)),
                  onDirectory: widget.onOpenDirectory,
                  onNearby: () => _push(widget.pages.nearby(_user)),
                ),
                const SizedBox(height: 12),
                _BusinessEntry(
                  future: _business,
                  onOpenMine: () =>
                      _pushThenRefresh(widget.pages.myBusinesses(_user)),
                  onRegister: () =>
                      _pushThenRefresh(widget.pages.registerBusiness(_user)),
                ),
                const SizedBox(height: 24),
                _sectionTitle(theme, 'Terbaru'),
                const SizedBox(height: 8),
                _LatestBlock<Map<String, dynamic>>(
                  key: const Key('latest-jobs'),
                  heading: 'Lowongan baru',
                  future: _jobs,
                  emptyIcon: Icons.work_outline,
                  emptyText:
                      'Belum ada lowongan. Lowongan baru akan muncul di sini.',
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
                  heading: 'Baru di Marketplace',
                  future: _listings,
                  emptyIcon: Icons.storefront_outlined,
                  emptyText:
                      'Belum ada produk. Produk yang disetujui akan muncul di sini.',
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
                actionLabel: 'Coba lagi',
                feedbackScreen: 'Home',
                error: snap.error,
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
            child: const Text('Lihat semua pengumuman'),
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
    required this.onDirectory,
    required this.onNearby,
  });

  final VoidCallback onJobs;
  final VoidCallback onMarketplace;
  final VoidCallback onDirectory;
  final VoidCallback onNearby;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Finding an alumnus is the main job of the app, so it is one wide
    // button; the rest are smaller shortcuts. Directory is also a bottom tab.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          key: const Key('tile-directory'),
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onDirectory,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.search, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cari alumni',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                        Text(
                          'Berdasarkan jurusan, angkatan, dan industri',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Tile(
                key: const Key('tile-jobs'),
                icon: Icons.work_outline,
                label: 'Jobs',
                subtitle: 'Lowongan dari alumni',
                onTap: onJobs,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                key: const Key('tile-marketplace'),
                icon: Icons.storefront_outlined,
                label: 'Marketplace',
                subtitle: 'Produk dan usaha alumni',
                onTap: onMarketplace,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Tile(
          key: const Key('tile-nearby'),
          icon: Icons.near_me_outlined,
          label: 'Nearby Alumni',
          subtitle: 'Alumni di kota yang sama denganmu',
          onTap: onNearby,
        ),
      ],
    );
  }
}

class _RequestsCard extends StatelessWidget {
  const _RequestsCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('home-requests-card'),
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.handshake_outlined, color: scheme.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$count alumni ingin terhubung denganmu. Lihat permintaan',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                actionLabel: 'Coba lagi',
                feedbackScreen: 'Home',
                error: snap.error,
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
    this.feedbackScreen,
    this.error,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// When set, an error card: adds a "Send feedback" button for this screen.
  final String? feedbackScreen;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
              if (actionLabel != null && feedbackScreen == null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          if (feedbackScreen != null)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (actionLabel != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                TextButton(
                  key: const Key('send-feedback'),
                  onPressed: () => showFeedbackSheet(
                    context,
                    error: error,
                    screen: feedbackScreen!,
                  ),
                  child: const Text('Send feedback'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// How long the green "your business is approved" card stays on Home.
const Duration kApprovedCardLifetime = Duration(days: 3);

/// The business the Home card talks about, or null when there is nothing
/// worth showing. A business that still needs attention (waiting, not
/// approved, suspended) always shows. An approved one shows only for
/// [kApprovedCardLifetime] after it was approved, then the card goes away
/// (My business in Profile still lists it).
Business? businessForHomeCard(List<Business> all, DateTime now) {
  bool fresh(Business b) {
    final since = b.reviewedAt ?? b.updatedAt ?? b.createdAt;
    return since == null || now.difference(since) < kApprovedCardLifetime;
  }

  // A recently approved one first, else whatever still needs attention.
  for (final b in all) {
    if (b.isApproved && fresh(b)) return b;
  }
  for (final b in all) {
    if (!b.isApproved) return b;
  }
  return null;
}

class _BusinessSummary {
  const _BusinessSummary(this.businesses, this.usage);
  final List<Business> businesses;
  final Map<String, BusinessUsage> usage;
}

/// The business card on Home: for an owner their status, band, products used
/// out of the limit and unlimited days left; for everyone else a "register
/// your business" card. A failed load shows nothing (Home is not blocked).
class _BusinessEntry extends StatelessWidget {
  const _BusinessEntry({
    required this.future,
    required this.onOpenMine,
    required this.onRegister,
  });

  final Future<_BusinessSummary> future;
  final VoidCallback onOpenMine;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_BusinessSummary>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.hasError) {
          return const SizedBox.shrink();
        }
        final summary = snap.data!;
        final all = summary.businesses;
        if (all.isEmpty) {
          return Card(
            key: const Key('business-register-card'),
            elevation: 0,
            color: theme.colorScheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Punya usaha? Biar sesama alumni bisa menemukannya.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  FilledButton(
                    key: const Key('business-register-button'),
                    onPressed: onRegister,
                    child: const Text('Daftarkan'),
                  ),
                ],
              ),
            ),
          );
        }
        final b = businessForHomeCard(all, DateTime.now());
        // Everything is approved and the news is old: nothing to show.
        if (b == null) return const SizedBox.shrink();
        final u = summary.usage[b.id];
        final lines = <String>[
          b.approvedBand != null
              ? 'Skala: ${b.approvedBand!.label}'
              : 'Skala pilihanmu: ${b.requestedBand?.label ?? '-'}',
          if (b.isApproved && u != null) postingSummary(b, u),
          if (b.status == BusinessStatus.rejected && b.rejectionReason != null)
            'Alasan: ${b.rejectionReason}',
          if (all.length > 1) '+ ${all.length - 1} more',
        ];
        return Card(
          key: const Key('business-owner-card'),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onOpenMine,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Chip(
                        key: const Key('business-status-chip'),
                        label: Text(b.status.label),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  for (final l in lines)
                    Text(
                      l,
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
        );
      },
    );
  }
}
