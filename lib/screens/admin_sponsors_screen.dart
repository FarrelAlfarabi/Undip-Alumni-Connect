import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/marketplace_image_picker.dart';
import '../data/sponsor.dart';
import '../util/app_language.dart';
import '../util/friendly_error.dart';
import '../util/safe_url.dart';
import '../widgets/error_view.dart';
import 'photo_adjust_screen.dart';
import '../widgets/sponsor_banner.dart' show kSponsorAspectRatio;

/// Admin > Sponsor: every sponsor of the Home carousel, hidden and
/// out-of-date ones too. The database refuses every change for non-admins.
class AdminSponsorsScreen extends StatefulWidget {
  const AdminSponsorsScreen({
    super.key,
    required this.adminId,
    required this.repository,
    this.pickImage = pickListingImage,
    this.uploadImage = uploadSponsorImage,
  });

  final String adminId;
  final AdminRepository repository;
  final ImagePickerFn pickImage;
  final SponsorImageUploader uploadImage;

  @override
  State<AdminSponsorsScreen> createState() => _AdminSponsorsScreenState();
}

class _AdminSponsorsScreenState extends State<AdminSponsorsScreen> {
  late Future<List<Sponsor>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.sponsors(widget.adminId);
  }

  void _reload() => setState(() {
    _future = widget.repository.sponsors(widget.adminId);
  });

  Future<void> _edit([Sponsor? sponsor]) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SponsorFormScreen(
          adminId: widget.adminId,
          repository: widget.repository,
          sponsor: sponsor,
          pickImage: widget.pickImage,
          uploadImage: widget.uploadImage,
        ),
      ),
    );
    if (message == null || !mounted) return;
    _reload();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(message))));
  }

  static String _day(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  String _status(Sponsor s) {
    final now = DateTime.now();
    if (!s.active) return tr('Disembunyikan');
    if (!s.isLive(now)) return tr('Di luar tanggal tayang');
    return tr('Tayang');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Sponsor'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('sponsor-new'),
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: Text(tr('Tambah sponsor')),
      ),
      body: FutureBuilder<List<Sponsor>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              message: snap.error is AdminException
                  ? adminErrorMessage(snap.error!)
                  : friendlyLoadError('sponsor', snap.error),
              screen: 'Admin Sponsor',
              error: snap.error,
              onRetry: _reload,
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'Belum ada sponsor. Kalau kosong, kotak sponsor tidak '
                    'tampil di Home.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              for (final s in items)
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
                      key: Key('sponsor-admin-${s.id}'),
                      title: Text(s.name),
                      subtitle: Text(
                        '${_status(s)} · ${tr('Urutan')} ${s.rank}\n'
                        '${s.views} ${tr('dilihat')} · ${s.taps} ${tr('diketuk')}'
                        '${s.startsOn == null ? '' : '\n${tr('Mulai')} ${_day(s.startsOn!)}'}'
                        '${s.endsOn == null ? '' : ' · ${tr('Sampai')} ${_day(s.endsOn!)}'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _edit(s),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Add or change one sponsor. Pops a short message after a save or delete.
class SponsorFormScreen extends StatefulWidget {
  const SponsorFormScreen({
    super.key,
    required this.adminId,
    required this.repository,
    required this.pickImage,
    required this.uploadImage,
    this.sponsor,
  });

  final String adminId;
  final AdminRepository repository;
  final ImagePickerFn pickImage;
  final SponsorImageUploader uploadImage;
  final Sponsor? sponsor;

  @override
  State<SponsorFormScreen> createState() => _SponsorFormScreenState();
}

class _SponsorFormScreenState extends State<SponsorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.sponsor?.name);
  late final _link = TextEditingController(text: widget.sponsor?.linkUrl);
  late final _rank = TextEditingController(
    text: (widget.sponsor?.rank ?? 1).toString(),
  );
  late DateTime? _starts = widget.sponsor?.startsOn;
  late DateTime? _ends = widget.sponsor?.endsOn;
  late bool _active = widget.sponsor?.active ?? true;
  PickedImage? _picked;
  bool _imageMissing = false;
  String? _imageError;
  bool _busy = false;

  bool get _hasImage =>
      _picked != null || (widget.sponsor?.imageUrl ?? '').isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    _rank.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    try {
      final raw = await widget.pickImage();
      if (raw == null || !mounted) return;
      final cropped = await PhotoAdjust.run(
        context,
        raw,
        aspectRatio: kSponsorAspectRatio,
      );
      if (cropped == null || !mounted) return;
      setState(() {
        _picked = cropped;
        _imageMissing = false;
        _imageError = null;
      });
    } on ImagePickException catch (e) {
      if (mounted) setState(() => _imageError = tr(e.message));
    } catch (_) {
      if (mounted) {
        setState(
          () => _imageError = tr('Gambar tidak bisa dibuka. Coba lain.'),
        );
      }
    }
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final initial = (start ? _starts : _ends) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !mounted) return;
    setState(() => start ? _starts = d : _ends = d);
  }

  String? _checkLink(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return tr('Isi tautan sponsor.');
    final uri = parseHttpUrl(t);
    if (uri == null || uri.scheme != 'https' || t.length > 500) {
      return tr('Tautan harus diawali https://');
    }
    return null;
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AdminException
                ? (e.code == AdminErrorCode.invalidInput
                      ? tr(
                          'Data sponsor belum benar. Periksa nama, tautan '
                          '(https://...), gambar dan tanggal.',
                        )
                      : adminErrorMessage(e))
                : friendlyError(e),
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    if (!_hasImage) setState(() => _imageMissing = true);
    if (!formOk || !_hasImage) return;
    if (_starts != null && _ends != null && _ends!.isBefore(_starts!)) {
      setState(() => _imageError = tr('Tanggal berhenti harus setelah mulai.'));
      return;
    }
    final before = widget.sponsor;
    await _run(() async {
      final url = _picked != null
          ? await widget.uploadImage(_picked!)
          : before!.imageUrl;
      await widget.repository.saveSponsor(
        widget.adminId,
        id: before?.id,
        name: _name.text,
        imageUrl: url,
        // "mandiri.com" is saved as "https://mandiri.com".
        linkUrl: parseHttpUrl(_link.text)?.toString() ?? _link.text,
        startsOn: _starts,
        endsOn: _ends,
        rank: int.tryParse(_rank.text.trim()) ?? 1,
        active: _active,
      );
      return before == null ? 'Sponsor ditambahkan.' : 'Sponsor disimpan.';
    });
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Hapus sponsor ini?')),
        content: Text(
          tr(
            'Sponsor hilang dari Home dan tidak bisa dikembalikan. Pilih '
            'Sembunyikan kalau mau menyimpannya.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            key: const Key('sponsor-delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Hapus')),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _run(() async {
      await widget.repository.deleteSponsor(widget.adminId, widget.sponsor!.id);
      return 'Sponsor dihapus.';
    });
  }

  Widget _dateTile(String label, DateTime? value, bool start) {
    final text = value == null
        ? tr('Tanpa batas')
        : '${value.day.toString().padLeft(2, '0')}-'
              '${value.month.toString().padLeft(2, '0')}-${value.year}';
    return ListTile(
      key: Key(start ? 'sponsor-starts' : 'sponsor-ends'),
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(text),
      trailing: value == null
          ? const Icon(Icons.calendar_today_outlined)
          : IconButton(
              tooltip: tr('Hapus tanggal'),
              icon: const Icon(Icons.close),
              onPressed: _busy
                  ? null
                  : () => setState(() => start ? _starts = null : _ends = null),
            ),
      onTap: _busy ? null : () => _pickDate(start),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existingUrl = widget.sponsor?.imageUrl ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(widget.sponsor == null ? 'Tambah sponsor' : 'Ubah sponsor'),
        ),
        actions: [
          if (widget.sponsor != null)
            IconButton(
              key: const Key('sponsor-delete'),
              tooltip: tr('Hapus'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                key: const Key('sponsor-name'),
                controller: _name,
                enabled: !_busy,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: tr('Nama sponsor'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? tr('Isi nama sponsor.') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('sponsor-link'),
                controller: _link,
                enabled: !_busy,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: tr('Tautan (https://...)'),
                  border: const OutlineInputBorder(),
                ),
                validator: _checkLink,
              ),
              const SizedBox(height: 16),
              if (_picked != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: kSponsorAspectRatio,
                    child: Image.memory(
                      _picked!.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                )
              else if (existingUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: kSponsorAspectRatio,
                    child: Image.network(
                      existingUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('sponsor-choose-image'),
                onPressed: _busy ? null : _choose,
                icon: const Icon(Icons.image_outlined),
                label: Text(tr(_hasImage ? 'Ganti gambar' : 'Pilih gambar')),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr(
                    'Rasio 2:1 (misalnya 1600 x 800 px). JPG, PNG atau WebP, '
                    'maksimal 2 MB.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_imageMissing || _imageError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _imageError ?? tr('Pilih gambar sponsor.'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              _dateTile(tr('Mulai tayang'), _starts, true),
              _dateTile(tr('Berhenti tayang'), _ends, false),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('sponsor-rank'),
                controller: _rank,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('Urutan (angka kecil tampil lebih dulu)'),
                  border: const OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                key: const Key('sponsor-active'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Tampil di Home')),
                value: _active,
                onChanged: _busy ? null : (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'Anggota melihat label "Disponsori" di setiap sponsor. '
                  'Label ini tidak bisa diubah.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('sponsor-save'),
                onPressed: _busy ? null : _save,
                child: Text(tr('Simpan')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
