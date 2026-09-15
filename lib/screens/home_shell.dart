import 'package:flutter/material.dart';

import 'announcements_screen.dart';
import 'directory_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ProfileDetailScreen(profile: widget.profile, currentUser: _currentUser),
      DirectoryScreen(currentUser: _currentUser),
      JobBoardScreen(currentUser: _currentUser),
      MessagesListScreen(currentUser: _currentUser),
      const AnnouncementsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
