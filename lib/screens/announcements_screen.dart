import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/announcement_card.dart';
import '../widgets/load_error_view.dart';

/// Ikafe announcements feed (Day 7): one-way broadcast, no moderation, no
/// posting UI in the app — these are seeded/admin content, not something an
/// alumnus creates.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, this.showBack = false});

  /// True when pushed from the Home hub (shows a back arrow).
  final bool showBack;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchAnnouncements();
  }

  Future<List<Map<String, dynamic>>> _fetchAnnouncements() async {
    final rows = await Supabase.instance.client
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        automaticallyImplyLeading: widget.showBack,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return LoadErrorView(
              thing: 'announcements',
              error: snapshot.error,
              onRetry: () => setState(() => _future = _fetchAnnouncements()),
            );
          }

          final announcements = snapshot.data ?? [];
          if (announcements.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No announcements yet.'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _fetchAnnouncements());
              await _future;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: announcements.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  AnnouncementCard(a: announcements[i]),
            ),
          );
        },
      ),
    );
  }
}
