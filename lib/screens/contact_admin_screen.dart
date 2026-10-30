import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/support_config.dart';

/// Subject of the email a person writes to the admin team from the login flow.
const String kLoginMailSubject = 'Verifikasi alumni Lingkaran';

/// Body line for that email, or null when no email was typed yet. Built on the
/// spot and never stored.
String? loginMailBody(String email) {
  final e = email.trim();
  return e.isEmpty ? null : 'Email yang saya pakai: $e';
}

/// Profile > Kontak admin: the ways to reach the admin team. Each row can be
/// copied or opened in the right app. It needs no sign in, so the login screens
/// open it too ([fromLogin]).
class ContactAdminScreen extends StatelessWidget {
  const ContactAdminScreen({
    super.key,
    this.contacts = kSupportContacts,
    this.fromLogin = false,
    this.typedEmail = '',
  });

  final List<SupportContact> contacts;

  /// Opened from the login flow: shows the verification intro and fills the
  /// email subject.
  final bool fromLogin;

  /// The email the person typed on the login screen, put in the mail body.
  final String typedEmail;

  IconData _icon(SupportContactKind k) => switch (k) {
    SupportContactKind.email => Icons.email_outlined,
    SupportContactKind.whatsapp => Icons.chat_outlined,
    SupportContactKind.phone => Icons.phone_outlined,
  };

  void _copy(BuildContext context, SupportContact c) {
    Clipboard.setData(ClipboardData(text: c.value));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Tersalin: ${c.value}')));
  }

  Future<void> _open(BuildContext context, SupportContact c) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = fromLogin
        ? c.uriWith(subject: kLoginMailSubject, body: loginMailBody(typedEmail))
        : c.uri;
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Tidak bisa dibuka. Salin ${c.value} saja.'),
          action: SnackBarAction(
            label: 'Salin',
            onPressed: () => Clipboard.setData(ClipboardData(text: c.value)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kontak admin')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              fromLogin
                  ? 'Belum terdaftar, lupa email yang dipakai, atau kode tidak '
                        'masuk? Hubungi tim admin. Input nama lengkap, angkatan, '
                        'dan jurusanmu.'
                  : 'Butuh bantuan, ingin melaporkan masalah, atau butuh lebih '
                        'dari 3 usaha? Hubungi tim admin di sini.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final c in contacts)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: ListTile(
                  key: Key('support-${c.kind.name}'),
                  leading: Icon(_icon(c.kind)),
                  title: Text(c.label),
                  subtitle: Text(c.value),
                  onTap: () => _open(context, c),
                  trailing: IconButton(
                    tooltip: 'Salin',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => _copy(context, c),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
