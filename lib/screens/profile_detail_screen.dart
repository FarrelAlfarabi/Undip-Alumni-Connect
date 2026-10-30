import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../data/admin_repository.dart';
import '../data/avatar_repository.dart';
import '../data/contact_repository.dart';
import '../data/report_repository.dart';
import '../lock/lock_service.dart';
import '../models/contact_request.dart';
import '../lock/session.dart';
import '../policy/policy_screen.dart';
import '../util/friendly_error.dart';
import '../widgets/avatar.dart';
import '../widgets/content_actions_menu.dart';
import 'admin_screen.dart';
import 'my_businesses_screen.dart';
import 'my_job_postings_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';
import 'profile_photo_screen.dart';
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
    this.nimLoader,
    this.lock,
  });

  /// The device lock. Injectable for tests; defaults to the real one.
  final LockService? lock;

  /// Asks the database whether this profile is an admin. Injectable for
  /// tests. Asked once per session (when the Profile tab is built) and
  /// never cached on the device.
  final Future<bool> Function(String profileId)? adminCheck;

  /// Asks the database for this profile's NIM on behalf of the viewer. It
  /// answers only for the profile's owner and for admins; everyone else gets
  /// null, and NIM is not shown. Injectable for tests.
  final Future<String?> Function(String viewerId, String profileId)? nimLoader;

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
  /// A lock exists on this build (web included).
  bool get _lockOn => widget.lock?.enabled ?? true;

  late Map<String, dynamic> _profile;
  bool _messaging = false;
  Future<bool>? _isAdmin;
  Future<String?>? _nim;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _nim = _askNim();
    if (widget.showEditButton) {
      _isAdmin = _askAdmin();
    } else if (!_isOwnProfile) {
      _loadRequestSent();
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

  // NIM is private: the database returns it to the owner and admins only. A
  // failed or empty answer just leaves the NIM row out.
  Future<String?> _askNim() async {
    try {
      final viewer = widget.currentUser.value['id'] as String;
      final profile = _profile['id'] as String;
      final ask = widget.nimLoader ?? _rpcNim;
      return await ask(viewer, profile);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _rpcNim(String viewerId, String profileId) async {
    final result = await Supabase.instance.client.rpc(
      'profile_nim',
      params: {'p_viewer': viewerId, 'p_profile': profileId},
    );
    return result is String && result.isNotEmpty ? result : null;
  }

  bool get _isOwnProfile => _profile['id'] == widget.currentUser.value['id'];

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => ProfileSetupScreen(profile: _profile)),
    );
    if (updated != null) {
      // The edit screen does not read the photo link; keep the one we have.
      final merged = {'avatar_url': _profile['avatar_url'], ...updated};
      setState(() => _profile = merged);
      if (_isOwnProfile) {
        widget.currentUser.value = merged;
      }
    }
  }

  Future<void> _editPhoto() async {
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ProfilePhotoScreen(
          profileId: _profile['id'] as String,
          name: _profile['name'] as String? ?? '',
          currentUrl: _profile['avatar_url'] as String?,
          repository: AvatarRepository(),
        ),
      ),
    );
    if (url == null) return;
    final next = {..._profile, 'avatar_url': url.isEmpty ? null : url};
    setState(() => _profile = next);
    if (_isOwnProfile) widget.currentUser.value = next;
  }

  // True when I already have a request to this person that is waiting for
  // an answer. Then the button says so instead of inviting a second request.
  bool _requestSent = false;

  Future<void> _loadRequestSent() async {
    try {
      final mine = await (widget.contactRepository ?? ContactRepository())
          .outgoing(widget.currentUser.value['id'] as String);
      final id = _profile['id'];
      final open = mine.any(
        (r) => r.targetId == id && r.status == ContactRequestStatus.pending,
      );
      if (open && mounted) setState(() => _requestSent = true);
    } catch (_) {
      // Unknown: keep the normal button. A second send is refused anyway.
    }
  }

  Future<void> _requestContact() async {
    final sent = await showRequestContactSheet(
      context,
      repository: widget.contactRepository ?? ContactRepository(),
      requesterId: widget.currentUser.value['id'] as String,
      targetId: _profile['id'] as String,
      targetName: _profile['name'] as String? ?? 'alumni ini',
    );
    if (sent && mounted) setState(() => _requestSent = true);
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
        title: Text(widget.showEditButton ? 'Profil Saya' : 'Profil Alumni'),
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
      // The main action on someone else's profile stays on screen while the
      // page scrolls, instead of sitting under both panels.
      bottomNavigationBar: !widget.showEditButton && !_isOwnProfile
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _contactActions(theme),
                  ),
                ),
              ),
            )
          : null,
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
                              SizedBox(
                                width: _isOwnProfile ? 84 : 64,
                                height: _isOwnProfile ? 84 : 64,
                                child: Stack(
                                  children: [
                                    Avatar(
                                      url: _profile['avatar_url'] as String?,
                                      name: _profile['name'] as String? ?? '',
                                      radius: 32,
                                    ),
                                    if (_isOwnProfile)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: IconButton.filled(
                                          key: const Key('avatar-edit'),
                                          tooltip: 'Ubah foto profil',
                                          onPressed: _editPhoto,
                                          icon: const Icon(
                                            Icons.photo_camera_outlined,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
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
                                    if ((_profile['city'] as String?)
                                            ?.trim()
                                            .isNotEmpty ??
                                        false)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          key: const Key('profile-city-line'),
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 16,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                (_profile['city'] as String)
                                                    .trim(),
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          ],
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
                          const SizedBox(height: 20),
                          if (widget.showEditButton) ...[
                            _panel(
                              theme,
                              icon: Icons.school_outlined,
                              title: 'Academic',
                              children: [
                                FutureBuilder<String?>(
                                  future: _nim,
                                  builder: (context, snap) {
                                    final nim = snap.data;
                                    if (nim == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return _field(theme, 'NIM', nim);
                                  },
                                ),
                                _field(theme, 'Faculty', _profile['faculty']),
                                _field(theme, 'Major', _profile['major']),
                                _field(
                                  theme,
                                  'Graduation Year',
                                  _profile['graduation_year']?.toString(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _panel(
                              theme,
                              icon: Icons.work_outline,
                              title: 'Employment',
                              action: widget.showEditButton
                                  ? TextButton.icon(
                                      key: const Key('profile-edit'),
                                      onPressed: _editProfile,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Edit'),
                                    )
                                  : null,
                              children: [
                                _field(
                                  theme,
                                  'Current Role',
                                  _profile['current_role'],
                                ),
                                _field(theme, 'Industry', _profile['industry']),
                                // Profiles saved before the two employer fields
                                // were merged may only have current_employer.
                                _field(
                                  theme,
                                  'Company',
                                  _profile['company'] ??
                                      _profile['current_employer'],
                                ),
                              ],
                            ),
                          ] else ...[
                            _panel(
                              theme,
                              icon: Icons.work_outline,
                              title: 'Employment',
                              action: widget.showEditButton
                                  ? TextButton.icon(
                                      key: const Key('profile-edit'),
                                      onPressed: _editProfile,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Edit'),
                                    )
                                  : null,
                              children: [
                                _field(
                                  theme,
                                  'Current Role',
                                  _profile['current_role'],
                                ),
                                _field(theme, 'Industry', _profile['industry']),
                                // Profiles saved before the two employer fields
                                // were merged may only have current_employer.
                                _field(
                                  theme,
                                  'Company',
                                  _profile['company'] ??
                                      _profile['current_employer'],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _panel(
                              theme,
                              icon: Icons.school_outlined,
                              title: 'Academic',
                              children: [
                                FutureBuilder<String?>(
                                  future: _nim,
                                  builder: (context, snap) {
                                    final nim = snap.data;
                                    if (nim == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return _field(theme, 'NIM', nim);
                                  },
                                ),
                                _field(theme, 'Faculty', _profile['faculty']),
                                _field(theme, 'Major', _profile['major']),
                                _field(
                                  theme,
                                  'Graduation Year',
                                  _profile['graduation_year']?.toString(),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (widget.showEditButton) ...[
                    const SizedBox(height: 16),
                    _ProfileMenu(
                      adminFuture: _isAdmin,
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
                      onPolicy: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PolicyScreen()),
                      ),
                      onHelp: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      ),
                      onAdmin: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminScreen(
                            adminId: widget.currentUser.value['id'] as String,
                          ),
                        ),
                      ),
                      // Back to verification with the whole shell torn down,
                      // so a second account starts from a clean state. Also
                      // forgets this device's remembered person and PIN
                      // (local only).
                      onSignOut: () =>
                          signOutTo(context, const VerificationScreen()),
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

  List<Widget> _contactActions(ThemeData theme) => [
    if (_requestSent) ...[
      FilledButton.tonalIcon(
        key: const Key('request-sent'),
        onPressed: null,
        icon: const Icon(Icons.hourglass_top),
        label: const Text('Permintaan terkirim'),
      ),
      const SizedBox(height: 6),
      Text(
        'Sedang menunggu jawaban. Kamu akan dapat notifikasi saat ada '
        'jawaban.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ] else
      FilledButton.icon(
        key: const Key('request-contact'),
        onPressed: _requestContact,
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Minta kontak'),
      ),
    if (widget.chat) ...[
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _messaging ? null : _messageThisAlumnus,
        icon: _messaging
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.chat_bubble_outline),
        label: const Text('Message'),
      ),
    ],
  ];

  /// A soft inner panel for one group of facts: icon and small-caps title on
  /// the left, an optional action (Edit) on the right, then the rows.
  Widget _panel(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<Widget> children,
    Widget? action,
  }) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  /// Label above value, so a long value never squeezes the label and the two
  /// always line up.
  Widget _field(ThemeData theme, String label, String? value) {
    final display = (value == null || value.isEmpty) ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(display, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Under my own profile: Admin (admins only),
/// then My business and My job postings, then Settings, Privacy policy and Help, then Sign out.
/// Rarely used things (PIN, blocked users, delete account, contact admin,
/// feedback, about) live inside Settings and Help.
class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.adminFuture,
    required this.onBusiness,
    required this.onJobs,
    required this.onSettings,
    required this.onPolicy,
    required this.onHelp,
    required this.onAdmin,
    required this.onSignOut,
  });

  final Future<bool>? adminFuture;
  final VoidCallback onBusiness;
  final VoidCallback onJobs;
  final VoidCallback onSettings;
  final VoidCallback onPolicy;
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
              child: MenuList(
                items: [
                  MenuItem(
                    key: const Key('profile-admin'),
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin',
                    onTap: onAdmin,
                  ),
                ],
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
              key: const Key('profile-policy'),
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy policy and community rules',
              onTap: onPolicy,
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
