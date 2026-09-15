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
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ProfileDetailScreen(profile: widget.profile),
      DirectoryScreen(currentProfile: widget.profile),
      JobBoardScreen(currentProfile: widget.profile),
      MessagesListScreen(currentProfile: widget.profile),
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
