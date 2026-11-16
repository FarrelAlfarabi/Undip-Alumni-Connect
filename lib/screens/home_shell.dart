import 'package:flutter/foundation.dart' show kIsWeb, setEquals;

import '../util/app_language.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/feature_flags.dart';
import '../data/block_list.dart';
import '../data/home_repository.dart';
import '../data/category_repository.dart';
import '../data/marketplace_repository.dart';
import '../platform/app_location.dart';
import '../platform/breakpoints.dart';
import '../theme.dart';
import 'home_pages.dart';
import 'home_screen.dart';
import '../widgets/brand_lockup.dart';

/// App shell with a bottom navigation: Home, Directory, Market, Profile (and
/// Chat when [chatEnabled] is on). Lands on Home after verification. Market
/// has three segments, Products, Businesses and Jobs. News, Kontak Ikafe,
/// Requests and Notifications are opened from the Home hub (tiles, banners,
/// icons) as pushed screens with a back arrow.
///
/// Owns the single [ValueNotifier] that represents "the logged-in user"
/// for the whole session and passes the same reference to every tab (see
/// profile_detail_screen.dart's doc comment), so an edit made on one screen
/// shows up on every other screen.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.profile,
    this.pages = const HomePages(),
    this.homeApi,
    this.marketplaceRepository,
    this.autoAdvance = const Duration(seconds: 5),
    this.chat = chatEnabled,
    this.refreshAfter = const Duration(minutes: 2),
  });

  /// A tab you left is refetched when you come back to it only if you were
  /// away at least this long. Inside the window it comes back instantly, with
  /// what it already had, instead of a spinner on every tap. Tests pass
  /// [Duration.zero] to refetch on every entry.
  final Duration refreshAfter;

  /// Whether the Chat tab exists. Defaults to the app-wide [chatEnabled]
  /// switch; tests pass it to check both states.
  final bool chat;

  final Map<String, dynamic> profile;

  /// Injectable for tests; defaults to the real screens.
  final HomePages pages;
  final HomeApi? homeApi;
  final MarketplaceRepository? marketplaceRepository;
  final Duration autoAdvance;

  static const homeTab = 0;
  static const directoryTab = 1;
  static const marketTab = 2;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = HomeShell.homeTab;
  late final ValueNotifier<Map<String, dynamic>> _currentUser;
  final _stackKey = GlobalKey();

  /// Desktop only: screens opened from a tab (News, Requests, Notifications,
  /// Admin) open in this navigator, inside the content column, so the side
  /// nav stays. Phones and tablets keep opening them over the whole screen.
  final _innerNav = GlobalKey<NavigatorState>();

  // Home (latest jobs/listings/news), Directory, Market and Chat show data
  // that changes while the app is open (a conversation you just started, a
  // job someone just posted). IndexedStack keeps a visited tab alive, so such
  // a tab would otherwise show whatever it fetched the first time forever.
  // Bumping a tab's epoch gives it a new key, which recreates it and so
  // refetches. It happens when the tab was left for [HomeShell.refreshAfter]
  // or longer, and for every tab when the people I blocked change, so a block
  // shows at once.
  final Map<int, int> _epoch = {};
  int _epochOf(int tab) => _epoch[tab] ?? 0;
  void _bump(int tab) => _epoch[tab] = _epochOf(tab) + 1;

  // Tabs are built the first time they are opened, not all at launch. Before
  // this, every tab fetched its data while the first screen was still
  // loading. Once built, IndexedStack keeps a tab alive (scroll position,
  // filters).
  final Set<int> _visited = {HomeShell.homeTab};
  final Map<int, DateTime> _leftAt = {};
  Set<String> _lastBlocked = const {};

  /// Which Market segment is showing: 0 Products, 1 Businesses.
  final ValueNotifier<int> _marketSegment = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _currentUser = ValueNotifier(widget.profile);
    // Web: open the tab named in the address (a refresh or a shared link).
    final (place, segment) = AppLocation.takeInitial();
    final start = _indexOf(place);
    if (start != null) {
      _index = start;
      _visited.add(start);
      if (place == ShellPlace.explore) _marketSegment.value = segment;
    }
    _marketSegment.addListener(_reportPlace);
    _reportPlace();
    // Who I blocked: asked once per session, used by every list.
    BlockList.shared.load(widget.profile['id'] as String);
    // Categories for Explore and the forms: asked once per session.
    CategoryRepository.shared.load();
    _lastBlocked = {...BlockList.shared.blocked.value};
    BlockList.shared.blocked.addListener(_onBlockedChanged);
  }

  void _onBlockedChanged() {
    final now = BlockList.shared.blocked.value;
    if (setEquals(now, _lastBlocked)) return;
    _lastBlocked = {...now};
    if (!mounted) return;
    setState(() {
      for (final tab in _refreshable) {
        _bump(tab);
      }
    });
  }

  @override
  void dispose() {
    BlockList.shared.blocked.removeListener(_onBlockedChanged);
    _marketSegment.removeListener(_reportPlace);
    // The shell is gone (Keluar, Ganti akun): the address goes back to the
    // start so the next person does not land on this person's tab.
    AppLocation.report(AppLocation.pathFor(ShellPlace.home));
    _currentUser.dispose();
    _marketSegment.dispose();
    super.dispose();
  }

  // Tab order: Home, Directory, Market, [Chat], Profile.
  int get _chatTab => widget.chat ? 3 : -1;
  int get _profileTab => widget.chat ? 4 : 3;

  /// The tab for [place], or null when it does not exist (Chat switched off).
  int? _indexOf(ShellPlace place) => switch (place) {
    ShellPlace.home => HomeShell.homeTab,
    ShellPlace.members => HomeShell.directoryTab,
    ShellPlace.explore => HomeShell.marketTab,
    ShellPlace.chat => widget.chat ? _chatTab : null,
    ShellPlace.profile => _profileTab,
  };

  ShellPlace _placeOf(int index) {
    if (index == HomeShell.directoryTab) return ShellPlace.members;
    if (index == HomeShell.marketTab) return ShellPlace.explore;
    if (index == _chatTab) return ShellPlace.chat;
    if (index == _profileTab) return ShellPlace.profile;
    return ShellPlace.home;
  }

  void _reportPlace() {
    final place = _placeOf(_index);
    AppLocation.report(
      AppLocation.pathFor(
        place,
        segment: place == ShellPlace.explore ? _marketSegment.value : 0,
      ),
    );
  }

  @visibleForTesting
  void debugSetMarketSegment(int segment) => _marketSegment.value = segment;

  void _openMarket(int segment) {
    _marketSegment.value = segment;
    _select(HomeShell.marketTab);
  }

  // Tabs that show data which changes while the app is open. Profile reads
  // the shared user notifier, so it never needs refetching.
  List<int> get _refreshable => [
    HomeShell.homeTab,
    HomeShell.directoryTab,
    HomeShell.marketTab,
    if (widget.chat) _chatTab,
  ];

  void _select(int i) {
    // A side nav tap closes any screen opened on top of the tabs.
    _innerNav.currentState?.popUntil((r) => r.isFirst);
    setState(() {
      if (i != _index) {
        final now = DateTime.now();
        _leftAt[_index] = now;
        final left = _leftAt[i];
        if (left != null &&
            _refreshable.contains(i) &&
            now.difference(left) >= widget.refreshAfter) {
          _bump(i);
        }
      }
      _visited.add(i);
      _index = i;
    });
    _reportPlace();
  }

  // Back from any tab first brings you back to the first tab (Home). Back
  // from Home asks "Exit the app?" and only leaves on Exit.
  bool _askingToExit = false;

  void _handlePop(bool didPop) {
    if (didPop) return;
    final inner = _innerNav.currentState;
    if (inner != null && inner.canPop()) {
      inner.maybePop();
      return;
    }
    if (_index != HomeShell.homeTab) {
      _select(HomeShell.homeTab);
      return;
    }
    // A browser has no app to exit: the tab or window is closed by the person,
    // so the dialog would only get in the way of the back button.
    if (kIsWeb) return;
    _confirmExit();
  }

  Future<void> _confirmExit() async {
    if (_askingToExit) return;
    _askingToExit = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('exit-dialog'),
        title: Text(tr('Exit the app?')),
        actions: [
          TextButton(
            key: const Key('exit-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Stay')),
          ),
          FilledButton(
            key: const Key('exit-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Exit')),
          ),
        ],
      ),
    );
    _askingToExit = false;
    if (leave != true || !mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    // Index of each tab in the stack. Unvisited tabs are an empty box, so
    // their page is not even created until the first visit.
    final chatTab = _chatTab;
    final profileTab = _profileTab;
    Widget tab(int index, Widget Function() build) =>
        _visited.contains(index) ? build() : const SizedBox.shrink();
    final tabs = [
      tab(
        HomeShell.homeTab,
        () => HomeScreen(
          key: ValueKey('home-${_epochOf(HomeShell.homeTab)}'),
          currentUser: _currentUser,
          onOpenDirectory: () => _select(HomeShell.directoryTab),
          onOpenMarket: _openMarket,
          pages: pages,
          api: widget.homeApi,
          marketplaceRepository: widget.marketplaceRepository,
          autoAdvance: widget.autoAdvance,
        ),
      ),
      tab(
        HomeShell.directoryTab,
        () => KeyedSubtree(
          key: ValueKey('directory-${_epochOf(HomeShell.directoryTab)}'),
          child: pages.directory(_currentUser),
        ),
      ),
      tab(
        HomeShell.marketTab,
        () => KeyedSubtree(
          key: ValueKey('market-${_epochOf(HomeShell.marketTab)}'),
          child: pages.market(_currentUser, _marketSegment),
        ),
      ),
      if (widget.chat)
        tab(
          chatTab,
          () => KeyedSubtree(
            key: ValueKey('chat-${_epochOf(chatTab)}'),
            child: pages.chat(_currentUser),
          ),
        ),
      tab(profileTab, () => pages.profile(widget.profile, _currentUser)),
    ];

    final destinations = [
      const _Place('Home', Icons.home_outlined, Icons.home),
      const _Place('Members', Icons.people_outline, Icons.people),
      const _Place('Explore', Icons.public_outlined, Icons.public),
      if (widget.chat)
        const _Place('Chat', Icons.chat_bubble_outline, Icons.chat_bubble),
      const _Place('Profile', Icons.person_outline, Icons.person),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final step = stepForWidth(constraints.maxWidth);
          // Phone: the tab fills the width, exactly as before. Wider: a
          // centred column so lines do not stretch across the screen.
          final desktop = step == ScreenStep.desktop;
          final room = constraints.maxWidth - (desktop ? _SideNav.width : 0);
          final stack = IndexedStack(
            key: _stackKey,
            index: _index,
            children: tabs,
          );
          final content = Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              key: const Key('shell-content'),
              width: room < shellContentWidth(constraints.maxWidth)
                  ? room
                  : shellContentWidth(constraints.maxWidth),
              height: double.infinity,
              // The global key keeps every tab alive (scroll, filters) when
              // the window is resized across the desktop width.
              child: desktop
                  ? Navigator(
                      key: _innerNav,
                      pages: [
                        MaterialPage(key: const ValueKey('tabs'), child: stack),
                      ],
                      onDidRemovePage: (_) {},
                    )
                  : stack,
            ),
          );
          if (desktop) {
            return Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SideNav(
                    places: destinations,
                    selected: _index,
                    onSelect: _select,
                  ),
                  Expanded(child: content),
                ],
              ),
            );
          }
          return Scaffold(
            body: content,
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.hairline)),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                destinations: [
                  for (final d in destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Place {
  const _Place(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Desktop navigation (1024 px and wider): the app logo, then one row per
/// tab, on the left edge. Replaces the bottom bar.
class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.places,
    required this.selected,
    required this.onSelect,
  });

  static const double width = 232;

  final List<_Place> places;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('side-nav'),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.hairline)),
      ),
      child: SizedBox(
        width: width,
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BrandLockup(),
                  ),
                ),
                for (var i = 0; i < places.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Semantics(
                      selected: i == selected,
                      button: true,
                      child: Material(
                        color: i == selected
                            ? scheme.secondaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: Key('side-nav-${places[i].label}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelect(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  i == selected
                                      ? places[i].selectedIcon
                                      : places[i].icon,
                                  color: i == selected
                                      ? scheme.onSecondaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    places[i].label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: i == selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: i == selected
                                          ? scheme.onSecondaryContainer
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
