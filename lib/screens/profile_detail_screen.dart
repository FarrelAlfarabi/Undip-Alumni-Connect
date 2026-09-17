import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'profile_setup_screen.dart';
import 'subscribe_screen.dart';
import 'verification_screen.dart';

/// Read-only view of an alumnus's profile. Identity fields (name, NIM,
/// faculty, major, graduation year) came from verification and aren't
/// editable here — only employment fields are, via ProfileSetupScreen.
///
/// [showEditButton] controls whether this is "my profile" (verification
/// flow — edit button shown; directory/jobs/messages/news are reached via
/// HomeShell's bottom nav, not from here) or someone else's profile viewed
/// from the directory (read-only, email hidden, subscription-gated
/// "Message" button).
///
/// [currentUser] is the logged-in user's profile as a shared
/// [ValueNotifier], not a plain map — subscription_status is checked and
/// mutated from several independent screens (job contact gate, messaging
/// gate), and a plain map snapshot went stale across screens (subscribing
/// via one job's detail view didn't unlock another job's contact info,
/// since each screen held its own copy). Passing the same notifier
/// reference everywhere means every screen reads the current value.
class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({
    super.key,
    required this.profile,
    required this.currentUser,
    this.showEditButton = true,
  });

  /// The profile being displayed — own or someone else's.
  final Map<String, dynamic> profile;
  final bool showEditButton;
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late Map<String, dynamic> _profile;
  bool _messaging = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  bool get _isOwnProfile => _profile['id'] == widget.currentUser.value['id'];

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => ProfileSetupScreen(profile: _profile)),
    );
    if (updated != null) {
      setState(() => _profile = updated);
      if (_isOwnProfile) {
        widget.currentUser.value = updated;
      }
    }
  }

  Future<void> _messageThisAlumnus() async {
    var viewer = widget.currentUser.value;

    if (viewer['subscription_status'] != 'subscribed') {
      final updated = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => SubscribeScreen(profile: viewer)),
      );
      if (updated == null) return;
      widget.currentUser.value = updated;
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
        // Own profile is the Profile tab's root (HomeShell index 0) — no
        // back arrow, matching every other bottom-nav tab. Someone else's
        // profile is a real pushed screen (from the Directory, a job
        // poster's name, etc.), where a back arrow is correct.
        automaticallyImplyLeading: !widget.showEditButton,
        actions: [
          if (widget.showEditButton)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () {
                // Back to verification with the whole shell torn down, so
                // a second demo account starts from a clean state.
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const VerificationScreen()),
                  (_) => false,
                );
              },
            ),
        ],
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
                          if (widget.showEditButton) ...[
                            const SizedBox(height: 12),
                            ValueListenableBuilder<Map<String, dynamic>>(
                              valueListenable: widget.currentUser,
                              builder: (context, user, _) {
                                if (user['subscription_status'] !=
                                    'subscribed') {
                                  return const SizedBox.shrink();
                                }
                                return Chip(
                                  avatar: Icon(
                                    Icons.workspace_premium_outlined,
                                    size: 16,
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                  label: const Text('Subscribed'),
                                  backgroundColor:
                                      theme.colorScheme.secondaryContainer,
                                  labelStyle: TextStyle(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                  side: BorderSide.none,
                                  visualDensity: VisualDensity.compact,
                                );
                              },
                            ),
                          ],
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
                  ] else if (!_isOwnProfile) ...[
                    const SizedBox(height: 20),
                    ValueListenableBuilder<Map<String, dynamic>>(
                      valueListenable: widget.currentUser,
                      builder: (context, user, _) {
                        return FilledButton.icon(
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
                            user['subscription_status'] == 'subscribed'
                                ? 'Message'
                                : 'Subscribe to Message',
                          ),
                        );
                      },
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
