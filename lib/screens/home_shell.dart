import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../data/block_list.dart';
import '../data/home_repository.dart';
import '../data/marketplace_repository.dart';
import 'home_pages.dart';
import 'home_screen.dart';

/// App shell with a bottom navigation: Home, Directory, Market, Profile (and
/// Chat when [chatEnabled] is on). Lands on Home after verification. Market
/// has two segments, Products and Businesses. Jobs, News, Nearby Alumni,
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
    // Who I blocked: asked once per session, used by every list.
    BlockList.shared.load(widget.profile['id'] as String);
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
    _currentUser.dispose();
    _marketSegment.dispose();
    super.dispose();
  }

  // Tab order: Home, Directory, Market, [Chat], Profile.
  int get _chatTab => widget.chat ? 3 : -1;

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
  }

  // Back from any tab first brings you back to the first tab (Home), and
  // only from Home does the route pop (and the app eventually exit).
  void _handlePop(bool didPop) {
    if (didPop) return;
    _select(HomeShell.homeTab);
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    // Index of each tab in the stack. Unvisited tabs are an empty box, so
    // their page is not even created until the first visit.
    final chatTab = _chatTab;
    final profileTab = widget.chat ? 4 : 3;
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

    return PopScope(
      canPop: _index == HomeShell.homeTab,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Directory',
            ),
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Market',
            ),
            if (widget.chat)
              const NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
