import 'package:flutter/material.dart';

import '../data/profile_fields.dart';
import '../theme.dart';

/// Profile > LinkedIn, Ubah. One optional link that other alumni see on my
/// profile. Only linkedin.com links are kept. Pops the updated profile row.
class ProfileLinkedInScreen extends StatefulWidget {
  const ProfileLinkedInScreen({super.key, required this.profile, this.save});

  final Map<String, dynamic> profile;
  final ProfileFieldSaver? save;

  @override
  State<ProfileLinkedInScreen> createState() => _ProfileLinkedInScreenState();
}

class _ProfileLinkedInScreenState extends State<ProfileLinkedInScreen> {
  late final _text = TextEditingController(
    text: widget.profile['linkedin_url'] as String? ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String? url;
    try {
      url = normalizeLinkedInUrl(_text.text);
    } on FormatException {
      setState(
        () => _error =
            'Isi tautan LinkedIn yang benar, contoh: '
            'linkedin.com/in/namamu',
      );
      return;
    }
    final changes = <String, dynamic>{'linkedin_url': url};
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await (widget.save ?? saveProfileFields)(
        widget.profile['id'] as String,
        changes,
      );
      if (!mounted) return;
      // No row back means nothing was stored.
      if (updated == null) throw StateError('link not saved');
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Tautan belum tersimpan. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('LinkedIn')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('linkedin-field'),
                controller: _text,
                enabled: !_saving,
                maxLength: kLinkedInMax,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'LinkedIn (opsional)',
                  hintText: 'linkedin.com/in/namamu',
                  helperText:
                      'Boleh dikosongkan. Tautan ini tampil di profilmu untuk '
                      'alumni lain.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('linkedin-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.black,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
