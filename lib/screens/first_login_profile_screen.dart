import 'package:flutter/material.dart';

import '../data/contact_repository.dart';
import 'default_contact_screen.dart';
import 'profile_setup_screen.dart';

/// Internal marker on the profile map handed over right after a person's first
/// consent. It is removed before the app sees the profile.
const String kFirstLoginKey = '_first_login';

/// Shown once, right after the first login and accepting the terms. Optional:
/// both buttons open the screens that already exist in Profile (the employment
/// editor and the default contact to share), and Skip goes straight in. It is
/// never shown again; after this everything lives under Profile.
class FirstLoginProfileScreen extends StatefulWidget {
  const FirstLoginProfileScreen({
    super.key,
    required this.profile,
    required this.onDone,
    this.contactRepository,
  });

  final Map<String, dynamic> profile;

  /// Called with the profile (updated if they saved the editor) to enter the app.
  final void Function(BuildContext context, Map<String, dynamic> profile)
  onDone;

  /// Injectable for tests.
  final ContactRepository? contactRepository;

  @override
  State<FirstLoginProfileScreen> createState() =>
      _FirstLoginProfileScreenState();
}

class _FirstLoginProfileScreenState extends State<FirstLoginProfileScreen> {
  late Map<String, dynamic> _profile = widget.profile;
  bool _profileSaved = false;
  bool _contactOpened = false;

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => ProfileSetupScreen(profile: _profile)),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _profile = {..._profile, ...updated};
      _profileSaved = true;
    });
  }

  Future<void> _editContact() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DefaultContactScreen(
          profileId: _profile['id'] as String,
          repository: widget.contactRepository,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _contactOpened = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (_profile['name'] as String?)?.trim() ?? '';
    final anyDone = _profileSaved || _contactOpened;
    return Scaffold(
      key: const Key('first-login-profile'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    name.isEmpty ? 'Selamat datang' : 'Selamat datang, $name',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Lengkapi profilmu agar sesama alumni lebih mudah '
                    'mengenalimu. Langkah ini opsional dan bisa kamu lewati. '
                    'Semuanya bisa diubah kapan saja di Profile.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    key: const Key('first-login-profile-edit'),
                    onPressed: _editProfile,
                    icon: Icon(
                      _profileSaved ? Icons.check_circle : Icons.work_outline,
                    ),
                    label: Text(
                      _profileSaved
                          ? 'Profil tersimpan'
                          : 'Isi profil (pekerjaan, industri, kota)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('first-login-contact-edit'),
                    onPressed: _editContact,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Kontak yang mau dibagikan'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kontak hanya dibagikan saat kamu menerima permintaan '
                    'kontak, dan kamu tetap mengonfirmasinya setiap kali.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  if (anyDone)
                    FilledButton(
                      key: const Key('first-login-continue'),
                      onPressed: () => widget.onDone(context, _profile),
                      child: const Text('Lanjut'),
                    )
                  else
                    TextButton(
                      key: const Key('first-login-skip'),
                      onPressed: () => widget.onDone(context, _profile),
                      child: const Text('Lewati'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
