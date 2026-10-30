import 'package:flutter/material.dart';

import '../data/contact_repository.dart';
import '../lock/lock_service.dart';
import '../lock/pin_settings_screen.dart';
import '../widgets/menu_list.dart';
import 'blocked_users_screen.dart';
import 'default_contact_screen.dart';
import 'delete_account_screen.dart';
import 'feature_intro_screen.dart';

/// Profile > Pengaturan: the things you set once and rarely come back to.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.currentUser,
    this.lock,
    this.showPin = true,
    this.contactRepository,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// The device lock. Defaults to the real one.
  final LockService? lock;

  /// False where there is no lock (the public web build): no PIN row.
  final bool showPin;

  final ContactRepository? contactRepository;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final me = currentUser.value['id'] as String;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MenuList(
              items: [
                MenuItem(
                  key: const Key('settings-default-contact'),
                  icon: Icons.contact_phone_outlined,
                  title: 'Default kontak untuk dibagikan',
                  subtitle: 'Terisi ketika menerima request',
                  onTap: () => _push(
                    context,
                    DefaultContactScreen(
                      profileId: me,
                      repository: contactRepository,
                    ),
                  ),
                ),
                MenuItem(
                  key: const Key('settings-intro'),
                  icon: Icons.tour_outlined,
                  title: 'Pengenalan fitur',
                  subtitle: 'Apa itu Marketplace, Business, dan Jobs',
                  onTap: () => _push(
                    context,
                    FeatureIntroScreen(
                      onDone: (ctx) async => Navigator.of(ctx).pop(),
                    ),
                  ),
                ),
                if (showPin)
                  MenuItem(
                    key: const Key('profile-pin'),
                    icon: Icons.pin_outlined,
                    title: 'PIN',
                    onTap: () => _push(
                      context,
                      PinSettingsScreen(lock: lock ?? LockService.shared),
                    ),
                  ),
                MenuItem(
                  key: const Key('profile-blocked'),
                  icon: Icons.block,
                  title: 'Blokir pengguna',
                  subtitle: 'Pengguna terblokir, buka blokir',
                  onTap: () =>
                      _push(context, BlockedUsersScreen(currentUserId: me)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Zona bahaya',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            MenuList(
              items: [
                MenuItem(
                  key: const Key('profile-delete'),
                  icon: Icons.delete_forever_outlined,
                  title: 'Hapus akun saya',
                  color: theme.colorScheme.error,
                  onTap: () => _push(
                    context,
                    DeleteAccountScreen(currentUser: currentUser),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
