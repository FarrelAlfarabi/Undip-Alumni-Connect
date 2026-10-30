import 'package:flutter/material.dart';

import '../data/profile_fields.dart';
import '../theme.dart';

/// Profile > Bio, Ubah. One short text (200 characters) that other alumni see
/// on my profile. Pops the updated profile row.
class ProfileBioScreen extends StatefulWidget {
  const ProfileBioScreen({super.key, required this.profile, this.save});

  final Map<String, dynamic> profile;
  final ProfileFieldSaver? save;

  @override
  State<ProfileBioScreen> createState() => _ProfileBioScreenState();
}

class _ProfileBioScreenState extends State<ProfileBioScreen> {
  late final _text = TextEditingController(
    text: widget.profile['bio'] as String? ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bio = _text.text.trim();
    final changes = <String, dynamic>{'bio': bio.isEmpty ? null : bio};
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
      Navigator.of(context).pop(updated ?? {...widget.profile, ...changes});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Bio belum tersimpan. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bio')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Perhatian: Dilarang menulis kata kasar, SARA, ujaran '
                  'kebencian, konten dewasa, atau data pribadi orang lain. '
                  'Bio yang dilaporkan bisa dihapus admin.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('bio-field'),
                controller: _text,
                enabled: !_saving,
                maxLength: kBioMax,
                maxLines: 5,
                minLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Ceritakan singkat tentang dirimu',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('bio-error'),
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
