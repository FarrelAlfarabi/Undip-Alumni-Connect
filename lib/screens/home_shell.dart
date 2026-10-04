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
  });

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

  // Home (latest jobs/listings/news) and Chat show data that changes while
  // the app is open (a conversation you just started from the directory, a
  // job someone just posted). IndexedStack keeps every tab alive, so those
  // tabs would otherwise show whatever they fetched at launch forever.
  // Bumping the key on re-select recreates the tab, which refetches. Jobs
  // and Marketplace are now pushed from Home, so they are built fresh (and
  // refetch) every time they are opened.
  int _homeEpoch = 0;
  int _chatEpoch = 0;

  /// Which Market segment is showing: 0 Products, 1 Businesses.
  final ValueNotifier<int> _marketSegment = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _currentUser = ValueNotifier(widget.profile);
    // Who I blocked: asked once per session, used by every list.
    BlockList.shared.load(widget.profile['id'] as String);
  }

  @override
  void dispose() {
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

  void _select(int i) {
    setState(() {
      if (i == HomeShell.homeTab && _index != HomeShell.homeTab) _homeEpoch++;
      if (i == _chatTab && _index != _chatTab) _chatEpoch++;
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
    final tabs = [
      HomeScreen(
        key: ValueKey('home-$_homeEpoch'),
        currentUser: _currentUser,
        onOpenDirectory: () => _select(HomeShell.directoryTab),
        onOpenMarket: _openMarket,
        pages: pages,
        api: widget.homeApi,
        marketplaceRepository: widget.marketplaceRepository,
        autoAdvance: widget.autoAdvance,
      ),
      pages.directory(_currentUser),
      pages.market(_currentUser, _marketSegment),
      if (widget.chat)
        KeyedSubtree(
          key: ValueKey('chat-$_chatEpoch'),
          child: pages.chat(_currentUser),
        ),
      pages.profile(widget.profile, _currentUser),
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
