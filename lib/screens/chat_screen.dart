import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util/friendly_error.dart';

/// Basic messaging UI (Day 6, demo scope). One conversation, no realtime —
/// the thread refetches after you send and polls every few seconds for
/// the other side's replies (the refresh button does it on demand). Messaging is only reachable once
/// subscribed (gated upstream in profile_detail_screen.dart).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.currentProfileId,
    required this.otherName,
  });

  final String conversationId;
  final String currentProfileId;
  final String otherName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>>? _messages;
  String? _loadError;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    // No realtime in this demo: check for new messages every few seconds so
    // a reply shows up without tapping refresh.
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(quiet: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Jumps the thread to the newest message, like any normal messenger.
  // Scheduled for after the frame that adds the new message, since the
  // scroll extent isn't known until that layout pass completes.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  // Keeps the current thread on screen while fetching, rather than
  // swapping the whole list for a spinner every time a message is sent.
  // [quiet] is the background poll: it only touches the screen when
  // something actually changed, so it never yanks the scroll position
  // while someone reads older messages, and never replaces a loaded
  // thread with an error on a flaky connection.
  Future<void> _refresh({bool quiet = false}) async {
    try {
      final rows = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);
      if (!mounted) return;
      final fresh = List<Map<String, dynamic>>.from(rows as List);
      final grew = fresh.length != (_messages?.length ?? -1);
      if (quiet && !grew) return;
      setState(() {
        _messages = fresh;
        _loadError = null;
      });
      if (!quiet || grew) _scrollToBottom();
    } catch (e) {
      if (!mounted || (quiet && _messages != null)) return;
      setState(() => _loadError = friendlyError(e));
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': widget.currentProfileId,
        'body': text,
      });
      _messageController.clear();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherName),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildThread(theme)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThread(ThemeData theme) {
    final messages = _messages;
    if (messages == null) {
      if (_loadError != null) {
        return Center(child: Text(_loadError!));
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Say hello to ${widget.otherName}.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final isMine = m['sender_id'] == widget.currentProfileId;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: isMine
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(m['body'] as String? ?? ''),
          ),
        );
      },
    );
  }
}
