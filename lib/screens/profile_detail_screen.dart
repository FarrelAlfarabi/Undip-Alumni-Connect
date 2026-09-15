import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'directory_screen.dart';
import 'job_board_screen.dart';
import 'messages_list_screen.dart';
import 'profile_setup_screen.dart';
import 'subscribe_screen.dart';

/// Read-only view of an alumnus's profile. Identity fields (name, NIM,
/// faculty, major, graduation year) came from verification and aren't
/// editable here — only employment fields are, via ProfileSetupScreen.
///
/// [showEditButton] controls whether this is "my profile" (verification
/// flow — edit button + directory/job board/messages entry points shown)
/// or someone else's profile viewed from the directory (read-only, email
/// hidden, subscription-gated "Message" button via [viewerProfile]).
class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({
    super.key,
    required this.profile,
    this.showEditButton = true,
    this.viewerProfile,
  });

  final Map<String, dynamic> profile;
  final bool showEditButton;

  /// The logged-in user viewing someone else's profile. Only relevant when
  /// [showEditButton] is false.
  final Map<String, dynamic>? viewerProfile;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late Map<String, dynamic> _profile;
  Map<String, dynamic>? _viewerProfile;
  bool _messaging = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _viewerProfile = widget.viewerProfile;
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => ProfileSetupScreen(profile: _profile)),
    );
    if (updated != null) {
      setState(() => _profile = updated);
    }
  }

  Future<void> _messageThisAlumnus() async {
    var viewer = _viewerProfile!;

    if (viewer['subscription_status'] != 'subscribed') {
      final updated = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => SubscribeScreen(profile: viewer)),
      );
      if (updated == null) return;
      setState(() => _viewerProfile = updated);
      viewer = updated;
    }

    setState(() => _messaging = true);
    try {
      final client = Supabase.instance.client;
      final viewerId = viewer['id'] as String;
      final otherId = _profile['id'] as String;

      final existing = await client
          .from('conversations')
          .select()
          .or(
            'and(participant_one.eq.$viewerId,participant_two.eq.$otherId),'
            'and(participant_one.eq.$otherId,participant_two.eq.$viewerId)',
          )
          .maybeSingle();

      final conversation =
          existing ??
          await client
              .from('conversations')
              .insert({'participant_one': viewerId, 'participant_two': otherId})
              .select()
              .single();

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversation['id'] as String,
            currentProfileId: viewerId,
            otherName: _profile['name'] as String? ?? 'Alumni',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open conversation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _messaging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showEditButton ? 'My Profile' : 'Alumni Profile'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Text(
                                  (_profile['name'] as String? ?? '?')
                                      .trim()
                                      .split(RegExp(r'\s+'))
                                      .map((w) => w.isNotEmpty ? w[0] : '')
                                      .take(2)
                                      .join()
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profile['name'] as String? ?? '',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (widget.showEditButton)
                                      Text(
                                        _profile['email'] as String? ?? '',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.verified,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          _section(theme, 'Academic'),
                          _field(theme, 'NIM', _profile['nim']),
                          _field(theme, 'Faculty', _profile['faculty']),
                          _field(theme, 'Major', _profile['major']),
                          _field(
                            theme,
                            'Graduation Year',
                            _profile['graduation_year']?.toString(),
                          ),
                          const SizedBox(height: 20),
                          _section(theme, 'Employment'),
                          _field(
                            theme,
                            'Current Employer',
                            _profile['current_employer'],
                          ),
                          _field(
                            theme,
                            'Current Role',
                            _profile['current_role'],
                          ),
                          _field(theme, 'Industry', _profile['industry']),
                          _field(theme, 'Company', _profile['company']),
                        ],
                      ),
                    ),
                  ),
                  if (widget.showEditButton) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Employment Info'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                DirectoryScreen(currentProfile: _profile),
                          ),
                        );
                      },
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Browse Alumni Directory'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                JobBoardScreen(currentProfile: _profile),
                          ),
                        );
                      },
                      icon: const Icon(Icons.work_outline),
                      label: const Text('Browse Job Board'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                MessagesListScreen(currentProfile: _profile),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Messages'),
                    ),
                  ] else if (_viewerProfile != null &&
                      _viewerProfile!['id'] != _profile['id']) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _messaging ? null : _messageThisAlumnus,
                      icon: _messaging
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      label: Text(
                        _viewerProfile!['subscription_status'] == 'subscribed'
                            ? 'Message'
                            : 'Subscribe to Message',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _field(ThemeData theme, String label, String? value) {
    final display = (value == null || value.isEmpty) ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(display, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
