import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ikafe_contact.dart';
import '../data/ikafe_contact_repository.dart';
import '../widgets/error_view.dart';

/// Home > Kontak Ikafe: the official Ikafe contacts and socials. Each row
/// opens the right app; the copy button copies the value.
class KontakIkafeScreen extends StatefulWidget {
  const KontakIkafeScreen({super.key, this.repository, this.showBack = true});

  final IkafeContactRepository? repository;
  final bool showBack;

  @override
  State<KontakIkafeScreen> createState() => _KontakIkafeScreenState();
}

class _KontakIkafeScreenState extends State<KontakIkafeScreen> {
  late final IkafeContactRepository _repo =
      widget.repository ?? IkafeContactRepository();
  late Future<IkafeContactList> _future = _repo.load();

  void _reload() => setState(() => _future = _repo.load());

  Future<void> _open(IkafeContact c) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(c.uri, mode: LaunchMode.externalApplication);
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

  void _copy(IkafeContact c) {
    Clipboard.setData(ClipboardData(text: c.value));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Tersalin: ${c.value}')));
  }

  IconData _icon(IkafeContactKind k) => switch (k) {
    IkafeContactKind.whatsapp => Icons.chat_outlined,
    IkafeContactKind.email => Icons.email_outlined,
    IkafeContactKind.instagram => Icons.camera_alt_outlined,
    IkafeContactKind.linkedin => Icons.work_outline,
    IkafeContactKind.website => Icons.language,
  };

  Widget _section(
    ThemeData theme,
    Key key,
    String title,
    List<IkafeContact> items,
  ) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        for (final c in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: ListTile(
                key: Key('ikafe-contact-${c.id}'),
                leading: Icon(_icon(c.kind)),
                title: Text(c.label),
                subtitle: Text(c.value),
                onTap: () => _open(c),
                trailing: IconButton(
                  tooltip: 'Salin',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => _copy(c),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontak Ikafe'),
        automaticallyImplyLeading: widget.showBack,
      ),
      body: FutureBuilder<IkafeContactList>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              message: 'Kontak belum bisa dimuat.',
              screen: 'Kontak Ikafe',
              error: snap.error,
              onRetry: _reload,
            );
          }
          final data = snap.data!;
          final hubungi = [
            for (final c in data.contacts)
              if (!c.kind.isSocial) c,
          ];
          final media = [
            for (final c in data.contacts)
              if (c.kind.isSocial) c,
          ];
          if (data.contacts.isEmpty) {
            return const Center(child: Text('Belum ada kontak.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.isPlaceholder)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Contoh data. Kontak resmi Ikafe menyusul.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (hubungi.isNotEmpty)
                _section(
                  theme,
                  const Key('ikafe-section-hubungi'),
                  'Hubungi',
                  hubungi,
                ),
              if (media.isNotEmpty)
                _section(
                  theme,
                  const Key('ikafe-section-media'),
                  'Media sosial',
                  media,
                ),
            ],
          );
        },
      ),
    );
  }
}
