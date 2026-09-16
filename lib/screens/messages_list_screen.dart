import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/filter_dropdown.dart';
import 'chat_screen.dart';

/// List of the current user's conversations (Day 6, demo scope). Empty
/// until they message someone from the directory — this screen doesn't
/// start new conversations itself.
///
/// Search + filter (added later) follow the same client-side pattern as
/// the Alumni Directory and Job Board — fine for a handful of demo
/// conversations, not meant to scale past the demo.
class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key, required this.currentUser});

  /// The logged-in user, as a shared notifier — only `.value['id']` is
  /// read here (a stable value), see profile_detail_screen.dart's doc
  /// comment for why this is a notifier rather than a plain map.
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  final _searchController = TextEditingController();
  String _faculty = kAllFilter;

  @override
  void initState() {
    super.initState();
    _future = _fetchConversations();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchConversations() async {
    final myId = widget.currentUser.value['id'] as String;
    final rows = await Supabase.instance.client
        .from('conversations')
        .select(
          '*, '
          'p1:alumni_profiles!conversations_participant_one_fkey(id, name, faculty), '
          'p2:alumni_profiles!conversations_participant_two_fkey(id, name, faculty)',
        )
        .or('participant_one.eq.$myId,participant_two.eq.$myId')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Map<String, dynamic> _otherParticipant(Map<String, dynamic> conversation) {
    final myId = widget.currentUser.value['id'] as String;
    final p1 = conversation['p1'] as Map<String, dynamic>;
    final p2 = conversation['p2'] as Map<String, dynamic>;
    return p1['id'] == myId ? p2 : p1;
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> conversations,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return conversations.where((c) {
      final other = _otherParticipant(c);
      if (_faculty != kAllFilter && other['faculty'] != _faculty) {
        return false;
      }
      if (query.isNotEmpty) {
        final name = (other['name'] as String? ?? '').toLowerCase();
        if (!name.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchController.text.isNotEmpty || _faculty != kAllFilter;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _faculty = kAllFilter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load messages: ${snapshot.error}'),
              ),
            );
          }

          final all = snapshot.data ?? [];
          if (all.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No conversations yet. Message an alumnus from the '
                  'directory to get started.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final conversations = _applyFilters(all);
          final faculties = distinctSortedValues(
            all.map(_otherParticipant).toList(),
            'faculty',
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClearableSearchField(
                  controller: _searchController,
                  hintText: 'Search by name...',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: FilterDropdown(
                  label: 'Faculty',
                  value: _faculty,
                  options: faculties,
                  onChanged: (v) => setState(() => _faculty = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: ClearFiltersButton(
                  active: _hasActiveFilters,
                  onPressed: _clearFilters,
                ),
              ),
              Expanded(
                child: conversations.isEmpty
                    ? const Center(
                        child: Text('No conversations match these filters.'),
                      )
                    : ListView.separated(
                        itemCount: conversations.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = conversations[i];
                          final other = _otherParticipant(c);
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(other['name'] as String? ?? 'Alumni'),
                            subtitle:
                                (other['faculty'] as String?)?.isNotEmpty ==
                                    true
                                ? Text(other['faculty'] as String)
                                : null,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    conversationId: c['id'] as String,
                                    currentProfileId:
                                        widget.currentUser.value['id']
                                            as String,
                                    otherName:
                                        other['name'] as String? ?? 'Alumni',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
