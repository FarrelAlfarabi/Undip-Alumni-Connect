import 'package:flutter/material.dart';

import 'directory_screen.dart';
import 'nearby_alumni_screen.dart';

/// Alumni section: Directory and Nearby as sibling tabs under one AppBar,
/// instead of Nearby being a small icon easy to miss in the Directory's
/// app bar (the original placement — user feedback confirmed it was
/// missable even after moving it to a Profile-tab card). A labeled tab
/// right where people already go to browse alumni is the most visible
/// place it can live without its own bottom-nav slot.
class AlumniScreen extends StatefulWidget {
  const AlumniScreen({
    super.key,
    required this.currentUser,
    this.initialTab = 0,
    this.showBack = false,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// 0 = Directory, 1 = Nearby. The Home tiles open Nearby directly.
  final int initialTab;

  /// True when pushed from the Home hub (a real route with a back arrow);
  /// false when it is a bottom-nav tab root.
  final bool showBack;

  @override
  State<AlumniScreen> createState() => _AlumniScreenState();
}

class _AlumniScreenState extends State<AlumniScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alumni'),
        automaticallyImplyLeading: widget.showBack,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Directory'),
            Tab(icon: Icon(Icons.near_me_outlined), text: 'Nearby'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DirectoryScreen(currentUser: widget.currentUser),
          NearbyAlumniScreen(currentUser: widget.currentUser),
        ],
      ),
    );
  }
}
