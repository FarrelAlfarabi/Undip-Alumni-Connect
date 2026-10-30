import 'package:flutter/material.dart';

import 'directory_screen.dart';

/// Alumni section: the Directory under one AppBar. Nearby Alumni was removed
/// when Kontak Ikafe replaced it on Home.
class AlumniScreen extends StatelessWidget {
  const AlumniScreen({
    super.key,
    required this.currentUser,
    this.showBack = false,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// True when pushed from the Home hub (a real route with a back arrow);
  /// false when it is a bottom-nav tab root.
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alumni'),
        automaticallyImplyLeading: showBack,
      ),
      body: DirectoryScreen(currentUser: currentUser),
    );
  }
}
