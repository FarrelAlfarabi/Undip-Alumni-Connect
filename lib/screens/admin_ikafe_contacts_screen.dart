import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/ikafe_contact.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';

/// Admin > Kontak Ikafe: the contacts and socials members see on Home. Shows
/// hidden rows too. The database refuses every change for non-admins.
class AdminIkafeContactsScreen extends StatefulWidget {
  const AdminIkafeContactsScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminIkafeContactsScreen> createState() =>
      _AdminIkafeContactsScreenState();
}

class _AdminIkafeContactsScreenState extends State<AdminIkafeContactsScreen> {
  late Future<List<IkafeContact>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.ikafeContacts(widget.adminId);
  }

  void _reload() => setState(() {
    _future = widget.repository.ikafeContacts(widget.adminId);
  });

  Future<void> _edit([IkafeContact? contact]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => IkafeContactFormScreen(
          adminId: widget.adminId,
          repository: widget.repository,
          contact: contact,
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kontak Ikafe')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('ikafe-contact-new'),
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Tambah kontak'),
      ),
      body: FutureBuilder<List<IkafeContact>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              message: snap.error is AdminException
                  ? adminErrorMessage(snap.error!)
                  : friendlyLoadError('kontak', snap.error),
              screen: 'Admin Kontak Ikafe',
              error: snap.error,
              onRetry: _reload,
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('Belum ada kontak.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
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
                      key: Key('ikafe-admin-${c.id}'),
                      title: Text(c.label),
                      subtitle: Text(
                        '${c.kind.title}: ${c.value}'
                        '${c.active ? '' : '\nDisembunyikan'}',
                      ),
                      isThreeLine: !c.active,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _edit(c),
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

/// Add or change one contact. Pops `true` after a save or delete.
class IkafeContactFormScreen extends StatefulWidget {
  const IkafeContactFormScreen({
    super.key,
    required this.adminId,
    required this.repository,
    this.contact,
  });

  final String adminId;
  final AdminRepository repository;
  final IkafeContact? contact;

  @override
  State<IkafeContactFormScreen> createState() => _IkafeContactFormScreenState();
}

class _IkafeContactFormScreenState extends State<IkafeContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.contact?.label);
  late final _value = TextEditingController(text: widget.contact?.value);
  late final _sort = TextEditingController(
    text: (widget.contact?.sortOrder ?? 0).toString(),
  );
  late IkafeContactKind _kind = widget.contact?.kind ?? IkafeContactKind.email;
  late bool _active = widget.contact?.active ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    _sort.dispose();
    super.dispose();
  }

  String? _checkValue(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Isi nilainya.';
    if (t.length > 200) return 'Terlalu panjang.';
    if (_kind == IkafeContactKind.email &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      return 'Isi email yang valid.';
    }
    if (_kind == IkafeContactKind.whatsapp &&
        !RegExp(r'^\+?[0-9 \-]{8,20}$').hasMatch(t)) {
      return 'Isi nomor dengan kode negara, misalnya +62812...';
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AdminException ? adminErrorMessage(e) : friendlyError(e),
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(
      () => widget.repository.saveIkafeContact(
        widget.adminId,
        id: widget.contact?.id,
        kind: _kind,
        label: _label.text,
        value: _value.text,
        sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
        active: _active,
      ),
    );
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus kontak ini?'),
        content: const Text(
          'Kontak hilang dari Kontak Ikafe. Pilih Sembunyikan kalau mau '
          'menyimpannya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('ikafe-delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _run(
      () => widget.repository.deleteIkafeContact(
        widget.adminId,
        widget.contact!.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact == null ? 'Tambah kontak' : 'Ubah kontak'),
        actions: [
          if (widget.contact != null)
            IconButton(
              key: const Key('ikafe-delete'),
              tooltip: 'Hapus',
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
              DropdownButtonFormField<IkafeContactKind>(
                key: const Key('ikafe-kind'),
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Jenis',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final k in IkafeContactKind.values)
                    DropdownMenuItem(value: k, child: Text(k.title)),
                ],
                onChanged: _busy
                    ? null
                    : (k) => setState(() => _kind = k ?? _kind),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('ikafe-label'),
                controller: _label,
                enabled: !_busy,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nama kontak',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Isi nama kontak.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('ikafe-value'),
                controller: _value,
                enabled: !_busy,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Nomor, email, @akun atau link',
                  border: OutlineInputBorder(),
                ),
                validator: _checkValue,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('ikafe-sort'),
                controller: _sort,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Urutan (angka kecil tampil lebih dulu)',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                key: const Key('ikafe-active'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Tampil di Kontak Ikafe'),
                value: _active,
                onChanged: _busy ? null : (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('ikafe-save'),
                onPressed: _busy ? null : _save,
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
