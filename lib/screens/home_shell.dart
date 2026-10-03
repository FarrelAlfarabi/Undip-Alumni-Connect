import 'package:flutter/material.dart';

import '../data/home_repository.dart';
import '../data/marketplace_repository.dart';
import 'home_pages.dart';
import 'home_screen.dart';

/// App shell with a 4-item bottom navigation: Home, Directory, Chat,
/// Profile. Lands on Home after verification. Jobs, News, Marketplace and
/// Nearby Alumni are opened from the Home hub (tiles, banners, "See all
/// announcements") as pushed screens with a back arrow.
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
  });

  final Map<String, dynamic> profile;

  /// Injectable for tests; defaults to the real screens.
  final HomePages pages;
  final HomeApi? homeApi;
  final MarketplaceRepository? marketplaceRepository;
  final Duration autoAdvance;

  static const homeTab = 0;
  static const directoryTab = 1;
  static const chatTab = 2;
  static const profileTab = 3;

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

  @override
  void initState() {
    super.initState();
    _currentUser = ValueNotifier(widget.profile);
  }

  @override
  void dispose() {
    _currentUser.dispose();
    super.dispose();
  }

  void _select(int i) {
    setState(() {
      if (i == HomeShell.homeTab && _index != HomeShell.homeTab) _homeEpoch++;
      if (i == HomeShell.chatTab && _index != HomeShell.chatTab) _chatEpoch++;
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
        pages: pages,
        api: widget.homeApi,
        marketplaceRepository: widget.marketplaceRepository,
        autoAdvance: widget.autoAdvance,
      ),
      pages.directory(_currentUser),
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Directory',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            NavigationDestination(
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
