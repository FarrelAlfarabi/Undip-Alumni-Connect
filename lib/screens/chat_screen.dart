import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Messaging UI with real Supabase Realtime (production-hardening stage 3
/// — see PROJECT_NOTES.md). A Postgres Changes subscription scoped to this
/// conversation pushes new messages as they're inserted, so the other
/// participant's replies show up without tapping refresh. Realtime
/// respects the messages table's RLS SELECT policy per subscriber, so this
/// subscription can only ever receive rows the signed-in user is already
/// allowed to read (a real participant of this conversation).
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
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _refresh();
    _subscribeToNewMessages();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToNewMessages() {
    _channel = Supabase.instance.client
        .channel('messages:conversation_id=eq.${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) => _addMessage(payload.newRecord),
        )
        .subscribe();
  }

  void _addMessage(Map<String, dynamic> row) {
    if (!mounted) return;
    setState(() {
      final existing = _messages ??= [];
      if (existing.any((m) => m['id'] == row['id'])) return;
      existing.add(row);
    });
    _scrollToBottom();
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

  Future<void> _refresh() async {
    try {
      final rows = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(rows as List);
        _loadError = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final row = await Supabase.instance.client
          .from('messages')
          .insert({
            'conversation_id': widget.conversationId,
            'sender_id': widget.currentProfileId,
            'body': text,
          })
          .select()
          .single();
      _messageController.clear();
      _addMessage(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
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
        return Center(child: Text('Failed to load messages: $_loadError'));
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
