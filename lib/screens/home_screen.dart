import 'package:flutter/material.dart';

import '../data/home_repository.dart';
import '../data/marketplace_format.dart';
import '../data/marketplace_repository.dart';
import '../data/posting_text.dart';
import '../models/business.dart';
import '../models/marketplace_listing.dart';
import '../theme.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/brand_lockup.dart';
import '../widgets/feedback_sheet.dart';
import '../widgets/upcoming_section.dart';
import 'home_pages.dart';
import 'marketplace_screen.dart' show ListingImage;
import 'profile_setup_screen.dart';

/// First name for the greeting: the first word of `name`, or null.
String? firstNameOf(Map<String, dynamic> profile) {
  final name = (profile['name'] as String? ?? '').trim();
  if (name.isEmpty) return null;
  return name.split(RegExp(r'\s+')).first;
}

/// Second greeting line: `<major> · Angkatan <year>`, only the parts that
/// exist, or the question when neither does.
String greetingSubtitle(Map<String, dynamic> profile) {
  final major = (profile['major'] as String? ?? '').trim();
  final year = profile['graduation_year']?.toString().trim() ?? '';
  final parts = [
    if (major.isNotEmpty) major,
    if (year.isNotEmpty) 'Angkatan $year',
  ];
  return parts.isEmpty
      ? 'Apa yang ingin kamu lakukan hari ini?'
      : parts.join(' · ');
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

  Future<List<Map<String, dynamic>>> _latestJobs() => homeJobs(_api);

  Future<List<MarketplaceListing>> _fetchListings() => homeListings(_market);

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([
      _announcements.catchError((_) => <Map<String, dynamic>>[]),
      _jobs.catchError((_) => <Map<String, dynamic>>[]),
      _listings.catchError((_) => <MarketplaceListing>[]),
    ]);
  }

  void _openJobs() => widget.onOpenMarket != null
      ? widget.onOpenMarket!(2)
      : _push(widget.pages.jobs(_user));

  void _openMarketplace() => widget.onOpenMarket != null
      ? widget.onOpenMarket!(0)
      : _push(widget.pages.marketplace(_user));

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

  // Directory and Jobs work best when a person has filled in
  // a city and a role, so Home keeps asking until both are there.
  bool get _profileIncomplete {
    bool empty(String k) => ((_user.value[k] as String?) ?? '').trim().isEmpty;
    return empty('city') || empty('current_role');
  }

  Future<void> _completeProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(profile: _user.value),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _user.value = updated);
    }
  }

  Future<void> _openRequests() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => widget.pages.requests(_user)));
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
        title: const BrandLockup(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.hairline),
        ),
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
        child: Column(
          children: [
            // Pinned: stays put while the sections below scroll.
            Material(
              color: theme.scaffoldBackgroundColor,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first == null ? 'Halo' : 'Halo, $first',
                      key: const Key('home-greeting'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      greetingSubtitle(_user.value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
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
                      const SizedBox(height: 8),
                      FutureBuilder<int>(
                        future: _pendingRequests,
                        builder: (context, snap) {
                          final n = snap.data ?? 0;
                          if (n <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RequestsCard(
                              count: n,
                              onTap: _openRequests,
                            ),
                          );
                        },
                      ),
                      if (_profileIncomplete)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            key: const Key('home-profile-card'),
                            color: theme.colorScheme.secondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppTheme.hairline),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _completeProfile,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Lengkapi profilmu: tambahkan kota dan '
                                        'pekerjaan agar alumni lain bisa menemukanmu.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      _bannerSection(theme),
                      const SizedBox(height: 8),
                      _QuickActions(
                        onJobs: _openJobs,
                        onMarketplace: _openMarketplace,
                        onDirectory: widget.onOpenDirectory,
                        onKontakIkafe: () =>
                            _push(widget.pages.kontakIkafe(_user)),
                      ),
                      const SizedBox(height: 12),
                      _BusinessEntry(
                        future: _business,
                        onOpenMine: () =>
                            _pushThenRefresh(widget.pages.myBusinesses(_user)),
                        onRegister: () => _pushThenRefresh(
                          widget.pages.registerBusiness(_user),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ProductsBlock(
                        future: _listings,
                        onRetry: () => setState(() {
                          _listings = _fetchListings();
                        }),
                        onSeeAll: _openMarketplace,
                        onOpen: (l) => _push(
                          widget.pages.listingDetail(l, _market, _user),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _LatestBlock<Map<String, dynamic>>(
                        key: const Key('latest-jobs'),
                        heading: 'Lowongan baru',
                        seeAllKey: const Key('latest-jobs-see-all'),
                        onSeeAll: _openJobs,
                        future: _jobs,
                        emptyIcon: Icons.work_outline,
                        emptyText: 'Belum ada lowongan. Lowongan baru akan muncul di sini.',
                        onRetry: () => setState(() {
                          _jobs = _latestJobs();
                        }),
                        builder: (jobs) => Column(
                          children: [
                            for (var i = 0; i < jobs.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              _JobRow(
                                job: jobs[i],
                                index: i,
                                onTap: () => _push(
                                  widget.pages.jobDetail(jobs[i], _user),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const UpcomingSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerSection(ThemeData theme) {
    final seeAll = TextButton(
      key: const Key('see-all-announcements'),
      onPressed: () => _push(widget.pages.announcements()),
      child: const Text('Lihat semua pengumuman'),
    );
    Widget withSeeAll(Widget card) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        Align(alignment: Alignment.centerRight, child: seeAll),
      ],
    );
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _announcements,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return withSeeAll(
            Container(
              key: const Key('banner-loading'),
              height: heroHeightFor(context),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError) {
          return withSeeAll(
            _MessageCard(
              key: const Key('banner-error'),
              icon: Icons.cloud_off_outlined,
              text: "Couldn't load announcements.",
              actionLabel: 'Coba lagi',
              feedbackScreen: 'Home',
              error: snap.error,
              onAction: () => setState(() {
                _announcements = _api.latestAnnouncements(kHomeBannerLimit);
              }),
            ),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) return withSeeAll(const WelcomeBannerCard());
        return BannerCarousel(
          items: items,
          autoAdvance: widget.autoAdvance,
          onOpen: (a) => _push(widget.pages.announcementDetail(a)),
          trailing: seeAll,
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onJobs,
    required this.onMarketplace,
    required this.onDirectory,
    required this.onKontakIkafe,
  });

  final VoidCallback onJobs;
  final VoidCallback onMarketplace;
  final VoidCallback onDirectory;
  final VoidCallback onKontakIkafe;

  @override
  Widget build(BuildContext context) {
    // 2 x 2 grid built from Rows so the height follows the content.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Tile(
                  key: const Key('tile-directory'),
                  icon: Icons.search,
                  iconBackground: AppTheme.blue,
                  iconColor: Colors.white,
                  label: 'Cari alumni',
                  hint: 'Berdasarkan jurusan, angkatan, dan industri',
                  onTap: onDirectory,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  key: const Key('tile-jobs'),
                  icon: Icons.work_outline,
                  iconBackground: AppTheme.blue,
                  iconColor: Colors.white,
                  label: 'Jobs',
                  hint: 'Lowongan dari alumni',
                  onTap: onJobs,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Tile(
                  key: const Key('tile-marketplace'),
                  icon: Icons.storefront_outlined,
                  iconBackground: AppTheme.yellow,
                  iconColor: AppTheme.black,
                  label: 'Marketplace',
                  hint: 'Produk dan usaha alumni',
                  onTap: onMarketplace,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  key: const Key('tile-kontak-ikafe'),
                  icon: Icons.contact_phone_outlined,
                  iconBackground: AppTheme.black,
                  iconColor: AppTheme.yellow,
                  label: 'Kontak Ikafe',
                  hint: 'Kontak dan media sosial resmi',
                  onTap: onKontakIkafe,
                ),
              ),
            ],
          ),
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.handshake_outlined, color: scheme.onSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$count alumni ingin terhubung denganmu. Lihat permintaan',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurface),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurface),
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
    required this.iconBackground,
    required this.iconColor,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String label;

  /// What the tile is for. Not drawn; read out by screen readers and shown as
  /// the long-press tooltip.
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: hint,
      child: Semantics(
        button: true,
        label: '$label. $hint',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Heading row: title on the left, blue "Lihat semua" link on the right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    required this.seeAllKey,
  });

  final String title;
  final VoidCallback onSeeAll;
  final Key seeAllKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          key: seeAllKey,
          style: TextButton.styleFrom(foregroundColor: AppTheme.blue),
          onPressed: onSeeAll,
          child: const Text('Lihat semua'),
        ),
      ],
    );
  }
}

/// Loading, error and empty states shared by both Home lists. [builder]
/// draws the list once there is at least one item.
class _LatestBlock<T> extends StatelessWidget {
  const _LatestBlock({
    super.key,
    required this.heading,
    required this.seeAllKey,
    required this.onSeeAll,
    required this.future,
    required this.builder,
    required this.emptyIcon,
    required this.emptyText,
    required this.onRetry,
  });

  final String heading;
  final Key seeAllKey;
  final VoidCallback onSeeAll;
  final Future<List<T>> future;
  final Widget Function(List<T> items) builder;
  final IconData emptyIcon;
  final String emptyText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: heading,
          onSeeAll: onSeeAll,
          seeAllKey: seeAllKey,
        ),
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
            return builder(items);
          },
        ),
      ],
    );
  }
}

/// "Baru di Marketplace": a horizontal row of product cards.
class _ProductsBlock extends StatelessWidget {
  const _ProductsBlock({
    required this.future,
    required this.onRetry,
    required this.onSeeAll,
    required this.onOpen,
  });

  final Future<List<MarketplaceListing>> future;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;
  final void Function(MarketplaceListing) onOpen;

  @override
  Widget build(BuildContext context) {
    return _LatestBlock<MarketplaceListing>(
      key: const Key('latest-listings'),
      heading: 'Baru di Marketplace',
      seeAllKey: const Key('latest-listings-see-all'),
      onSeeAll: onSeeAll,
      future: future,
      emptyIcon: Icons.storefront_outlined,
      emptyText: 'Belum ada produk. Produk yang disetujui akan muncul di sini.',
      onRetry: onRetry,
      builder: (items) => _ProductRow(items: items, onOpen: onOpen),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.items, required this.onOpen});

  final List<MarketplaceListing> items;
  final void Function(MarketplaceListing) onOpen;

  // Photo 93 + padding 10 + title 2 lines + category + city + price.
  static const double _cardWidth = 140;

  @override
  Widget build(BuildContext context) {
    // Cards in one row share a height that fits the text at the user's text
    // size, so the price is never cut and the row does not jump.
    final scale = MediaQuery.textScalerOf(context);
    final textHeight =
        scale.scale(13) * 1.3 * 2 +
        scale.scale(12) * 1.3 * 2 +
        scale.scale(14) * 1.3;
    final height = _cardWidth / 1.5 + 10 + textHeight + 6 + 14;
    return SizedBox(
      height: height,
      child: ListView.separated(
        key: const Key('latest-listings-row'),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) =>
            _ProductCard(listing: items[i], onTap: () => onOpen(items[i])),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.listing, required this.onTap});

  final MarketplaceListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final l = listing;
    return SizedBox(
      width: _ProductRow._cardWidth,
      child: Semantics(
        button: true,
        label: '${l.title}, ${formatRupiah(l.priceIdr)}',
        excludeSemantics: true,
        child: Material(
          key: const ValueKey('home-product-card'),
          color: AppTheme.paperRaised,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.hairline),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListingImage(
                  url: l.imageUrl,
                  aspectRatio: 3 / 2,
                  semanticLabel: l.title,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        l.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                      Text(
                        l.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                      Text(
                        formatRupiah(l.priceIdr),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to two letters from the company name ("Bank Mandiri" becomes "BM").
String companyInitials(String company) {
  final words = company
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w.substring(0, 1).toUpperCase()).join();
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job, required this.index, required this.onTap});

  final Map<String, dynamic> job;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = job['title'] as String? ?? '';
    final company = job['company'] as String? ?? '';
    final subtitle = [
      company,
      if ((job['industry'] as String?)?.isNotEmpty == true)
        job['industry'] as String,
    ].where((s) => s.isNotEmpty).join(' · ');
    final even = index.isEven;
    return Semantics(
      button: true,
      label: subtitle.isEmpty ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('home-job-row'),
        color: AppTheme.paperRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.hairline),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: even
                          ? theme.colorScheme.primaryContainer
                          : AppTheme.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      companyInitials(company),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: even ? AppTheme.blue : AppTheme.yellow,
                      ),
                    ),
                  ),
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
                            fontWeight: FontWeight.w700,
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
            color: AppTheme.yellow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Punya usaha? Biar sesama alumni bisa menemukannya.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const Key('business-register-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      shape: const StadiumBorder(),
                    ),
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
