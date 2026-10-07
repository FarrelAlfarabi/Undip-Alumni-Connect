import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../data/admin_repository.dart';
import '../data/contact_repository.dart';
import '../data/report_repository.dart';
import '../lock/lock_service.dart';
import '../lock/session.dart';
import '../util/friendly_error.dart';
import '../widgets/content_actions_menu.dart';
import 'admin_screen.dart';
import 'my_businesses_screen.dart';
import 'my_job_postings_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';
import 'profile_setup_screen.dart';
import 'request_contact_sheet.dart';
import 'verification_screen.dart';
import '../widgets/error_view.dart';
import '../widgets/menu_list.dart';

/// Read-only view of an alumnus's profile. Identity fields (name, NIM,
/// faculty, major, graduation year) came from verification and aren't
/// editable here — only employment fields are, via ProfileSetupScreen.
///
/// [showEditButton] controls whether this is "my profile" (verification
/// flow — edit button shown; directory/jobs/messages/news are reached via
/// HomeShell's bottom nav, not from here) or someone else's profile viewed
/// from the directory (read-only, email hidden, "Message" button).
///
/// [currentUser] is the logged-in user's profile as a shared
/// [ValueNotifier], not a plain map, so every screen reads the current value
/// after an edit made on another screen.
class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({
    super.key,
    required this.profile,
    required this.currentUser,
    this.showEditButton = true,
    this.chat = chatEnabled,
    this.contactRepository,
    this.adminCheck,
    this.unseenReportsCheck,
    this.lock,
  });

  /// The device lock. Injectable for tests; defaults to the real one.
  final LockService? lock;

  /// Asks the database whether this profile is an admin. Injectable for
  /// tests. Asked once per session (when the Profile tab is built) and
  /// never cached on the device.
  final Future<bool> Function(String profileId)? adminCheck;

  /// Number of reports no admin has seen yet (the badge on Admin). Injectable
  /// for tests.
  final Future<int> Function(String profileId)? unseenReportsCheck;

  /// Injectable for tests; defaults to the real repository.
  final ContactRepository? contactRepository;

  /// Whether the Message button shows (the app-wide chat switch).
  final bool chat;

  /// The profile being displayed — own or someone else's.
  final Map<String, dynamic> profile;
  final bool showEditButton;
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  /// A lock exists on this build (it is off on the public web build).
  bool get _lockOn => widget.lock?.enabled ?? !(kIsWeb && !kWebLockTest);

  late Map<String, dynamic> _profile;
  bool _messaging = false;
  Future<bool>? _isAdmin;
  Future<int>? _unseenReports;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    if (widget.showEditButton) {
      _isAdmin = _askAdmin();
      _unseenReports = _askUnseen();
    }
  }

  // A failed check just hides the Admin entry.
  Future<bool> _askAdmin() async {
    try {
      final id = widget.currentUser.value['id'] as String;
      final check = widget.adminCheck ?? AdminRepository().isAdmin;
      return await check(id);
    } catch (_) {
      return false;
    }
  }

  // A failed lookup just shows no number.
  Future<int> _askUnseen() async {
    try {
      final id = widget.currentUser.value['id'] as String;
      final ask =
          widget.unseenReportsCheck ?? AdminRepository().unseenReportsCount;
      return await ask(id);
    } catch (_) {
      return 0;
    }
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

  Future<void> _requestContact() async {
    await showRequestContactSheet(
      context,
      repository: widget.contactRepository ?? ContactRepository(),
      requesterId: widget.currentUser.value['id'] as String,
      targetId: _profile['id'] as String,
      targetName: _profile['name'] as String? ?? 'this alumnus',
    );
  }

  Future<void> _messageThisAlumnus() async {
    final viewer = widget.currentUser.value;

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
        showErrorSnackBar(
          context,
          message: friendlyError(e),
          screen: 'Profile',
          error: e,
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
          if (!widget.showEditButton)
            ContentActionsMenu(
              currentUserId: widget.currentUser.value['id'] as String,
              ownerId: _profile['id'] as String?,
              ownerName: _profile['name'] as String?,
              reportType: ReportTarget.profile,
              targetId: _profile['id'] as String?,
              what: 'this profile',
              onBlocked: () => Navigator.of(context).maybePop(),
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
                          Row(
                            children: [
                              Expanded(child: _section(theme, 'Employment')),
                              if (widget.showEditButton)
                                TextButton.icon(
                                  key: const Key('profile-edit'),
                                  onPressed: _editProfile,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Edit'),
                                ),
                            ],
                          ),
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
                    const SizedBox(height: 16),
                    _ProfileMenu(
                      adminFuture: _isAdmin,
                      unseenReports: _unseenReports,
                      onBusiness: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyBusinessesScreen(
                            ownerId: widget.currentUser.value['id'] as String,
                          ),
                        ),
                      ),
                      onJobs: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyJobPostingsScreen(
                            currentUser: widget.currentUser,
                          ),
                        ),
                      ),
                      onSettings: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            currentUser: widget.currentUser,
                            lock: widget.lock,
                            showPin: _lockOn,
                            contactRepository: widget.contactRepository,
                          ),
                        ),
                      ),
                      onHelp: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      ),
                      onAdmin: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminScreen(
                              adminId: widget.currentUser.value['id'] as String,
                            ),
                          ),
                        );
                        // The number may have changed while in Admin.
                        if (mounted) {
                          setState(() => _unseenReports = _askUnseen());
                        }
                      },
                      // Back to verification with the whole shell torn down,
                      // so a second account starts from a clean state. Also
                      // forgets this device's remembered person and PIN
                      // (local only).
                      onSignOut: () =>
                          signOutTo(context, const VerificationScreen()),
                    ),
                  ] else if (!_isOwnProfile) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('request-contact'),
                      onPressed: _requestContact,
                      icon: const Icon(Icons.person_add_alt_outlined),
                      label: const Text('Request to contact'),
                    ),
                    if (widget.chat) ...[
                      const SizedBox(height: 12),
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
                        label: const Text('Message'),
                      ),
                    ],
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

/// Under my own profile: Admin (admins only, with the unseen reports count),
/// then My business and My job postings, then Settings and Help, then Sign out.
/// Rarely used things (PIN, blocked users, policy, delete account, contact
/// admin, feedback, about) live inside Settings and Help.
class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.adminFuture,
    required this.unseenReports,
    required this.onBusiness,
    required this.onJobs,
    required this.onSettings,
    required this.onHelp,
    required this.onAdmin,
    required this.onSignOut,
  });

  final Future<bool>? adminFuture;
  final Future<int>? unseenReports;
  final VoidCallback onBusiness;
  final VoidCallback onJobs;
  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final VoidCallback onAdmin;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<bool>(
          future: adminFuture,
          builder: (context, snap) {
            if (snap.data != true) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FutureBuilder<int>(
                future: unseenReports,
                builder: (context, unseen) => MenuList(
                  items: [
                    MenuItem(
                      key: const Key('profile-admin'),
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin',
                      subtitle: (unseen.data ?? 0) > 0
                          ? '${unseen.data} new reports'
                          : null,
                      badge: unseen.data ?? 0,
                      onTap: onAdmin,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        MenuList(
          items: [
            MenuItem(
              key: const Key('profile-business'),
              icon: Icons.storefront_outlined,
              title: 'My business',
              onTap: onBusiness,
            ),
            MenuItem(
              key: const Key('profile-jobs'),
              icon: Icons.work_outline,
              title: 'My job postings',
              onTap: onJobs,
            ),
          ],
        ),
        const SizedBox(height: 12),
        MenuList(
          items: [
            MenuItem(
              key: const Key('profile-settings'),
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Default contact, PIN lock, blocked users, account',
              onTap: onSettings,
            ),
            MenuItem(
              key: const Key('profile-help'),
              icon: Icons.help_outline,
              title: 'Help',
              subtitle: 'Contact admin, send feedback, about',
              onTap: onHelp,
            ),
          ],
        ),
        const SizedBox(height: 12),
        MenuList(
          items: [
            MenuItem(
              key: const Key('profile-signout'),
              icon: Icons.logout,
              title: 'Sign out',
              onTap: onSignOut,
            ),
          ],
        ),
      ],
    );
  }
}
