import 'package:flutter/material.dart';

import 'alumni_screen.dart';
import 'announcements_screen.dart';
import 'job_board_screen.dart';
import 'messages_list_screen.dart';
import 'profile_detail_screen.dart';

/// App shell with bottom navigation (Day 7 polish pass): Profile, Alumni
/// directory, Jobs, Chat, News — mirrors the pitch deck's bottom nav
/// (Alumni/Jobs/Chat/News), with a Profile tab added since this app has no
/// separate top-bar avatar entry point. Lands on Profile right after
/// verification, matching the app's prior entry flow.
///
/// Owns the single [ValueNotifier] that represents "the logged-in user"
/// for the whole session and passes the same reference to every tab (see
/// profile_detail_screen.dart's doc comment) — subscribing from any one
/// screen updates every other screen's paywall/gate consistently.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final ValueNotifier<Map<String, dynamic>> _currentUser;

  // Jobs and Chat show data that changes while the app is open (a job you
  // just posted, a conversation you just started from the directory).
  // IndexedStack keeps every tab alive, so those tabs would otherwise show
  // whatever they fetched at launch forever. Bumping the key on re-select
  // recreates the tab, which refetches.
  int _jobsEpoch = 0;
  int _chatEpoch = 0;

  // Bumped (alongside forcing Alumni tab + sub-tab 1) when the Profile
  // tab's "Nearby Alumni" shortcut is tapped, so AlumniScreen is recreated
  // with a fresh TabController defaulting to Nearby instead of wherever it
  // was left.
  int _alumniEpoch = 0;
  int _alumniInitialTab = 0;

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
      if (i == 2 && _index != 2) _jobsEpoch++;
      if (i == 3 && _index != 3) _chatEpoch++;
      _index = i;
    });
  }

  void _openNearbyAlumni() {
    setState(() {
      _index = 1;
      _alumniInitialTab = 1;
      _alumniEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ProfileDetailScreen(
        profile: widget.profile,
        currentUser: _currentUser,
        onOpenNearby: _openNearbyAlumni,
      ),
      AlumniScreen(
        key: ValueKey('alumni-$_alumniEpoch'),
        currentUser: _currentUser,
        initialTabIndex: _alumniInitialTab,
      ),
      JobBoardScreen(
        key: ValueKey('jobs-$_jobsEpoch'),
        currentUser: _currentUser,
      ),
      MessagesListScreen(
        key: ValueKey('chat-$_chatEpoch'),
        currentUser: _currentUser,
      ),
      const AnnouncementsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Alumni',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'News',
          ),
        ],
      ),
    );
  }
}
