import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';

/// List of the current user's conversations (Day 6, demo scope). Empty
/// until they message someone from the directory — this screen doesn't
/// start new conversations itself.
class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key, required this.currentProfile});

  final Map<String, dynamic> currentProfile;

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchConversations();
  }

  Future<List<Map<String, dynamic>>> _fetchConversations() async {
    final myId = widget.currentProfile['id'] as String;
    final rows = await Supabase.instance.client
        .from('conversations')
        .select(
          '*, '
          'p1:alumni_profiles!conversations_participant_one_fkey(id, name), '
          'p2:alumni_profiles!conversations_participant_two_fkey(id, name)',
        )
        .or('participant_one.eq.$myId,participant_two.eq.$myId')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Map<String, dynamic> _otherParticipant(Map<String, dynamic> conversation) {
    final myId = widget.currentProfile['id'] as String;
    final p1 = conversation['p1'] as Map<String, dynamic>;
    final p2 = conversation['p2'] as Map<String, dynamic>;
    return p1['id'] == myId ? p2 : p1;
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

          final conversations = snapshot.data ?? [];
          if (conversations.isEmpty) {
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

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = conversations[i];
              final other = _otherParticipant(c);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(other['name'] as String? ?? 'Alumni'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: c['id'] as String,
                        currentProfileId: widget.currentProfile['id'] as String,
                        otherName: other['name'] as String? ?? 'Alumni',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
