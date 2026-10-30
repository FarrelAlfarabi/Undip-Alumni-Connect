import 'package:flutter/material.dart';

import '../data/avatar_repository.dart';
import '../data/marketplace_image_picker.dart';
import '../widgets/avatar.dart';
import '../widgets/image_size_hint.dart';

/// Choose, change or remove the profile photo. Pops with the new link, or
/// with an empty string when the photo was removed.
class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({
    super.key,
    required this.profileId,
    required this.name,
    required this.repository,
    this.currentUrl,
    this.pickPhoto = pickListingImage,
  });

  final String profileId;
  final String name;
  final String? currentUrl;
  final AvatarRepository repository;

  /// Injectable for tests; defaults to the file picker.
  final ImagePickerFn pickPhoto;

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  PickedImage? _picked;
  String? _error;
  bool _busy = false;

  bool get _hasCurrent => (widget.currentUrl ?? '').isNotEmpty;

  Future<void> _choose() async {
    setState(() => _error = null);
    try {
      final img = await widget.pickPhoto();
      if (img != null && mounted) setState(() => _picked = img);
    } on ImagePickException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Foto tidak bisa dibuka. Pilih foto lain.');
      }
    }
  }

  Future<void> _save() async {
    final img = _picked;
    if (img == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await widget.repository.upload(
        profileId: widget.profileId,
        fileName: img.name,
        bytes: img.bytes,
      );
      await widget.repository.setAvatar(widget.profileId, url);
      if (mounted) Navigator.of(context).pop(url);
    } on AvatarException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Foto belum tersimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.setAvatar(widget.profileId, null);
      if (mounted) Navigator.of(context).pop('');
    } on AvatarException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(title: const Text('Foto profil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: picked != null
                    ? ClipOval(
                        child: Image.memory(
                          picked.bytes,
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                          semanticLabel: 'Pratinjau foto profil',
                          errorBuilder: (_, _, _) =>
                              Avatar(url: null, name: widget.name, radius: 80),
                        ),
                      )
                    : Avatar(
                        url: widget.currentUrl,
                        name: widget.name,
                        radius: 80,
                      ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                key: const Key('photo-choose'),
                onPressed: _busy ? null : _choose,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  picked != null || _hasCurrent ? 'Ganti foto' : 'Pilih foto',
                ),
              ),
              const SizedBox(height: 8),
              const ImageSizeHint(ImageSizeKind.profile),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('photo-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('photo-save'),
                onPressed: _busy || picked == null ? null : _save,
                child: Text(_busy ? 'Menyimpan...' : 'Simpan'),
              ),
              if (_hasCurrent && picked == null) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('photo-remove'),
                  onPressed: _busy ? null : _remove,
                  child: const Text('Hapus foto'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
