import 'package:flutter/material.dart';

import '../data/bio_repository.dart';
import '../theme.dart';

/// Profile > Bio > Ubah: a short text about yourself, 200 characters at most.
/// Pops with the saved text (empty string when the bio was cleared).
class ProfileBioScreen extends StatefulWidget {
  const ProfileBioScreen({
    super.key,
    required this.profileId,
    this.initialBio,
    this.repository,
  });

  final String profileId;
  final String? initialBio;

  /// Injectable for tests; defaults to the real repository.
  final ProfileBioRepository? repository;

  @override
  State<ProfileBioScreen> createState() => _ProfileBioScreenState();
}

class _ProfileBioScreenState extends State<ProfileBioScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialBio ?? '',
  );
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final text = _controller.text.trim();
    try {
      await (widget.repository ?? ProfileBioRepository()).save(
        widget.profileId,
        text,
      );
      if (mounted) Navigator.of(context).pop(text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bio')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              key: const Key('bio-warning'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.yellowText),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Jangan menulis kata kasar, SARA, ujaran kebencian, '
                      'konten dewasa, atau data pribadi orang lain. Bio yang '
                      'dilaporkan bisa dihapus admin.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('profile-bio-field'),
              controller: _controller,
              enabled: !_saving,
              maxLength: kBioMaxLength,
              maxLines: 5,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              buildCounter: (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => Text('$currentLength/$maxLength'),
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Ceritakan singkat tentang dirimu',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Bio belum tersimpan. Periksa koneksi, lalu coba lagi.',
                  key: const Key('profile-bio-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('profile-bio-save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
