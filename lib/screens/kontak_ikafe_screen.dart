import 'package:flutter/material.dart';

import '../widgets/responsive_page.dart';

import '../util/app_language.dart';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ikafe_contact.dart';
import '../data/ikafe_contact_repository.dart';
import '../widgets/error_view.dart';

/// Home > Kontak Ikafe: the official Ikafe contacts and socials. Each row
/// opens the right app; the copy button copies the value.
class KontakIkafeScreen extends StatefulWidget {
  const KontakIkafeScreen({
    super.key,
    this.repository,
    this.showBack = true,
    this.launcher,
  });

  final IkafeContactRepository? repository;
  final bool showBack;

  /// Opens a link. Tests pass a stand-in; the app opens it in a new tab
  /// (web) or the right app (phone).
  final Future<bool> Function(Uri uri)? launcher;

  static Future<bool> defaultLauncher(Uri uri) => launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );

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
      ok = await (widget.launcher ?? KontakIkafeScreen.defaultLauncher)(c.uri);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(trf('Tidak bisa dibuka. Salin {0} saja.', [c.value])),
          action: SnackBarAction(
            label: tr('Salin'),
            onPressed: () => Clipboard.setData(ClipboardData(text: c.value)),
          ),
        ),
      );
    }
  }

  void _copy(IkafeContact c) {
    Clipboard.setData(ClipboardData(text: c.value));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(trf('Tersalin: {0}', [c.value]))));
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    key: Key('ikafe-contact-${c.id}'),
                    leading: Icon(_icon(c.kind)),
                    title: Text(c.label),
                    subtitle: Text(
                      c.value,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.colorScheme.primary,
                      ),
                    ),
                    onTap: () => _open(c),
                    trailing: IconButton(
                      tooltip: tr('Salin'),
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () => _copy(c),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        key: Key('ikafe-open-${c.id}'),
                        onPressed: () => _open(c),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(tr(c.kind.openLabel)),
                      ),
                    ),
                  ),
                ],
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
        title: Text(tr('Kontak Ikafe')),
        automaticallyImplyLeading: widget.showBack,
      ),
      body: ResponsivePage(
        builder: (_, _) => SafeArea(
          top: false,
          child: FutureBuilder<IkafeContactList>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErrorView(
                  message: tr('Kontak belum bisa dimuat.'),
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
                return Center(child: Text(tr('Belum ada kontak.')));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (data.isPlaceholder)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        tr('Contoh data. Kontak resmi Ikafe menyusul.'),
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
        ),
      ),
    );
  }
}
