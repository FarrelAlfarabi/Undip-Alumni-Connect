import 'package:flutter/material.dart';

import '../util/app_language.dart';

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

  Future<void> _pickLanguage(BuildContext context) async {
    final picked = await showDialog<AppLang>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('Pilih bahasa')),
        children: [
          for (final l in AppLang.values)
            SimpleDialogOption(
              key: Key('language-${l.name}'),
              onPressed: () => Navigator.of(ctx).pop(l),
              child: Row(
                children: [
                  Expanded(child: Text(l.label)),
                  if (l == AppLanguage.shared.current.value)
                    const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) await AppLanguage.shared.set(picked);
  }

  @override
  Widget build(BuildContext context) {
    final me = currentUser.value['id'] as String;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pengaturan'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MenuList(
              items: [
                MenuItem(
                  key: const Key('settings-default-contact'),
                  icon: Icons.contact_phone_outlined,
                  title: tr('Default kontak untuk dibagikan'),
                  subtitle: tr('Terisi ketika menerima request'),
                  onTap: () => _push(
                    context,
                    DefaultContactScreen(
                      profileId: me,
                      repository: contactRepository,
                    ),
                  ),
                ),
                MenuItem(
                  key: const Key('settings-language'),
                  icon: Icons.language,
                  title: tr('Bahasa'),
                  subtitle: AppLanguage.shared.current.value.label,
                  onTap: () => _pickLanguage(context),
                ),
                MenuItem(
                  key: const Key('settings-intro'),
                  icon: Icons.tour_outlined,
                  title: tr('Pengenalan fitur'),
                  subtitle: tr('Apa itu Marketplace, Business, dan Jobs'),
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
                  title: tr('Blokir pengguna'),
                  subtitle: tr('Pengguna terblokir, buka blokir'),
                  onTap: () =>
                      _push(context, BlockedUsersScreen(currentUserId: me)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              tr('Zona bahaya'),
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
                  title: tr('Hapus akun saya'),
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
