import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Group chat scoped to verified alumni in the same city — the demo
/// version of Master Plan §3.4 item 6's "easy way to network with nearby
/// alumni instead of chatting one by one" note. An alternative entry
/// point to nearby_alumni_screen.dart's per-person messaging: one thread
/// per city instead of N one-to-one conversations.
///
/// Any verified alumnus can read and post — there's no membership list
/// or invite mechanism. Same "guardrail not access control" RLS
/// limitation as the rest of this schema applies (see the migration that
/// added city_chat_messages).
class CityGroupChatScreen extends StatefulWidget {
  const CityGroupChatScreen({
    super.key,
    required this.city,
    required this.currentUser,
  });

  final String city;
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<CityGroupChatScreen> createState() => _CityGroupChatScreenState();
}

class _CityGroupChatScreenState extends State<CityGroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>>? _messages;
  String? _loadError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _refresh() async {
    try {
      final rows = await Supabase.instance.client
          .from('city_chat_messages')
          .select('*, sender:alumni_profiles(name)')
          .eq('city', widget.city)
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
      await Supabase.instance.client.from('city_chat_messages').insert({
        'city': widget.city,
        'sender_id': widget.currentUser.value['id'],
        'body': text,
      });
      _messageController.clear();
      await _refresh();
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
    final myId = widget.currentUser.value['id'];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.city} Alumni Group'),
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
          Container(
            width: double.infinity,
            color: theme.colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Demo group chat for verified alumni in ${widget.city}. '
              'Anyone verified can read and post here — there\'s no '
              'membership list yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          Expanded(child: _buildThread(theme, myId)),
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
                        hintText: 'Message the group...',
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

  Widget _buildThread(ThemeData theme, Object? myId) {
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
          'No messages yet. Say hello to ${widget.city} alumni.',
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
        final isMine = m['sender_id'] == myId;
        final senderName =
            (m['sender'] as Map<String, dynamic>?)?['name'] as String? ??
            'Alumni';
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Text(
                    senderName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Text(m['body'] as String? ?? ''),
              ],
            ),
          ),
        );
      },
    );
  }
}
