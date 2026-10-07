import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/support_config.dart';

/// Profile > Contact admin: the ways to reach the admin / customer service
/// team. Each row can be copied or opened in the right app.
class ContactAdminScreen extends StatelessWidget {
  const ContactAdminScreen({super.key, this.contacts = kSupportContacts});

  final List<SupportContact> contacts;

  IconData _icon(SupportContactKind k) => switch (k) {
    SupportContactKind.email => Icons.email_outlined,
    SupportContactKind.whatsapp => Icons.chat_outlined,
    SupportContactKind.phone => Icons.phone_outlined,
  };

  Future<void> _open(BuildContext context, SupportContact c) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(c.uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open it. Copy ${c.value} instead.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contact admin')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Need help, want to report a problem, or need more than 3 '
              'businesses? Reach the admin team here.',
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
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: c.value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Copied ${c.value}')),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
