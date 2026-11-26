import '../nav/back_guard.dart';

import 'package:flutter/material.dart';

import '../widgets/responsive_page.dart';

import '../util/app_language.dart';

import '../config/policy_config.dart';
import '../data/business_repository.dart';
import '../data/posting_text.dart';
import '../models/business.dart';
import '../models/business_edit_request.dart';
import '../util/friendly_error.dart';
import 'business_form_screen.dart';
import '../widgets/business_photo.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/error_view.dart';
import '../widgets/verified_badge.dart';
import '../data/profile_fields.dart';

const String _limitNote =
    'You can own up to $kMaxBusinesses businesses. To add more, email '
    '$kContactEmail.';

/// Shown while an admin has not decided yet.
const String kPendingReassurance =
    'Permintaanmu sudah kami terima dan sedang diproses admin. Kamu akan '
    'mendapat pemberitahuan di Notifikasi begitu ada keputusan.';

/// The owner's own businesses, with status, rejection reason and band.
/// A rejected business can be edited and sent again.
class MyBusinessesScreen extends StatefulWidget {
  const MyBusinessesScreen({super.key, required this.ownerId, this.repository});

  final String ownerId;
  final BusinessRepository? repository;

  @override
  State<MyBusinessesScreen> createState() => _MyBusinessesScreenState();
}

class _MyBusinessesScreenState extends State<MyBusinessesScreen> {
  late final BusinessRepository _repo =
      widget.repository ?? BusinessRepository();
  late Future<(List<Business>, List<BusinessUsage>)> _future;

  /// Open (or recently rejected) change requests, by business id.
  Map<String, BusinessEditRequest> _edits = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Business>, List<BusinessUsage>)> _load() async {
    final mine = await _repo.mine(widget.ownerId);
    final usage = await _repo.usage(widget.ownerId);
    final edits = await _repo.myEdits(widget.ownerId);
    _edits = {for (final r in edits) r.businessId: r};
    _activeCount = mine
        .where((b) => b.status != BusinessStatus.rejected)
        .length;
    return (mine, usage);
  }

  void _reload() => setState(() {
    _future = _load();
  });

  // Rejected businesses do not count towards the limit (same as the database).
  int _activeCount = 0;

  Future<void> _delete(Business b) async {
    final ok = await confirmDelete(
      context,
      title: tr('Hapus bisnis ini?'),
      body: trf('"{0}" dan semua produknya akan dihapus permanen.', [b.name]),
    );
    if (!ok || !mounted) return;
    try {
      await _repo.delete(widget.ownerId, b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Bisnis dihapus.'))));
      _reload();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          message: businessErrorMessage(e),
          screen: 'My businesses',
          error: e,
        );
      }
    }
  }

  /// Adds, changes or clears the NIB of a business that can no longer be
  /// edited in the form (already approved). A changed number loses its tick
  /// until an admin checks it again.
  Future<void> _editNib(Business b) async {
    final text = TextEditingController(text: b.nib ?? '');
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('NIB')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(
                  'Isi NIB (13 digit) usahamu. Admin akan mengeceknya, lalu '
                  'tanda centang biru muncul di usahamu. Kosongkan untuk '
                  'menghapus.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('nib-dialog-field'),
                controller: text,
                inputFormatters: const [CodePointLimit(13)],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('NIB (opsional)'),
                  border: const OutlineInputBorder(),
                ),
                validator: nibFieldError,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(text.text);
              }
            },
            child: Text(tr('Simpan')),
          ),
        ],
      ),
    );
    // The controller is not disposed here: the dialog is still animating out.
    if (value == null || !mounted) return;
    try {
      await _repo.setNib(widget.ownerId, b.id, value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('NIB disimpan. Admin akan mengeceknya.'))),
      );
      _reload();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          message: businessErrorMessage(e),
          screen: 'My businesses',
          error: e,
        );
      }
    }
  }

  Future<void> _cancelEdit(BusinessEditRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Batalkan permintaan perubahan?')),
        content: Text(tr('Data bisnismu tidak berubah.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Tidak')),
          ),
          FilledButton(
            key: const Key('cancel-edit-yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Batalkan')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.cancelEdit(widget.ownerId, r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Permintaan dibatalkan.'))));
      _reload();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          message: businessErrorMessage(e),
          screen: 'My businesses',
          error: e,
        );
      }
    }
  }

  Future<void> _openForm([Business? existing]) async {
    if (existing == null && _activeCount >= kMaxBusinesses) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(_limitNote))));
      return;
    }
    await Navigator.of(context).push<Business>(
      AppRoute(
        builder: (_) => BusinessFormScreen(
          ownerId: widget.ownerId,
          repository: _repo,
          existing: existing,
          pendingEdit: existing == null
              ? null
              : _edits[existing.id]?.isPending == true
              ? _edits[existing.id]
              : null,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('My businesses'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_business_outlined),
        label: Text(tr('Register a business')),
      ),
      body: ResponsivePage(
        builder: (_, _) => SafeArea(
          top: false,
          child: FutureBuilder<(List<Business>, List<BusinessUsage>)>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErrorView(
                  message: friendlyLoadError('your businesses', snap.error),
                  screen: 'My businesses',
                  error: snap.error,
                  onRetry: _reload,
                );
              }
              final items = snap.data?.$1 ?? const <Business>[];
              final usage = {
                for (final u in snap.data?.$2 ?? const <BusinessUsage>[])
                  u.businessId: u,
              };
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      trf(
                        'You have not registered a business yet. Register one so other alumni can find it.\n\n{0}',
                        [tr(_limitNote)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  try {
                    await _future;
                  } catch (_) {}
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        tr(_limitNote),
                        key: const Key('business-limit-note'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    final b = items[i - 1];
                    return BusinessOwnerCard(
                      business: b,
                      usage: usage[b.id],
                      onEdit: () => _openForm(b),
                      onEditNib: () => _editNib(b),
                      edit: _edits[b.id],
                      onCancelEdit: _edits[b.id] == null
                          ? null
                          : () => _cancelEdit(_edits[b.id]!),
                      onDelete: () => _delete(b),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One business as its owner sees it.
class BusinessOwnerCard extends StatelessWidget {
  const BusinessOwnerCard({
    super.key,
    required this.business,
    this.usage,
    this.onEdit,
    this.onEditNib,
    this.onDelete,
    this.edit,
    this.onCancelEdit,
  });

  final Business business;
  final BusinessUsage? usage;
  final VoidCallback? onEdit;
  final VoidCallback? onEditNib;
  final VoidCallback? onDelete;

  /// The open or recently rejected change request of this business.
  final BusinessEditRequest? edit;
  final VoidCallback? onCancelEdit;

  bool get _canEdit =>
      business.status == BusinessStatus.pending ||
      business.status == BusinessStatus.rejected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = business;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BusinessPhoto(url: b.photoUrl),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: NameWithBadge(
                      name: b.name,
                      verified: b.nibVerified && b.isApproved,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Not squeezed by the name: the whole status shows.
                Chip(
                  key: Key('status-${b.id}'),
                  label: Text(b.status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              b.isPersonal
                  ? '${b.category} · Run by the owner only'
                  : b.category,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              b.approvedBand != null
                  ? trf('Approved band: {0}', [b.approvedBand!.label])
                  : trf(
                      'Band you chose: {0} (an admin sets the approved band)',
                      [b.requestedBand?.label ?? '-'],
                    ),
              style: theme.textTheme.bodyMedium,
            ),
            if (b.nib != null) ...[
              const SizedBox(height: 4),
              Text(
                b.nibVerified
                    ? trf('NIB {0}: terverifikasi', [b.nib])
                    : trf('NIB {0}: Menunggu pengecekan NIB', [b.nib]),
                key: Key('nib-status-${b.id}'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (b.status == BusinessStatus.approved && usage != null) ...[
              const SizedBox(height: 4),
              Text(
                postingSummary(b, usage),
                key: Key('usage-${b.id}'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (b.status == BusinessStatus.pending) ...[
              const SizedBox(height: 8),
              Text(
                kPendingReassurance,
                key: Key('pending-note-${b.id}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (b.isHidden) ...[
              const SizedBox(height: 8),
              Text(
                trf(
                  'Hidden by an admin{0}. Other people cannot see this business or its products.',
                  [b.hiddenReason != null ? ': ${b.hiddenReason}' : ''],
                ),
                key: Key('hidden-${b.id}'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (b.status == BusinessStatus.rejected) ...[
              const SizedBox(height: 8),
              Text(
                trf('Reason: {0}', [b.rejectionReason ?? tr('not given')]),
                key: Key('reason-${b.id}'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (b.status == BusinessStatus.suspended) ...[
              const SizedBox(height: 8),
              Text(tr('This business is suspended. Please contact an admin.')),
            ],
            if (onDelete != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('delete-${b.id}'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(tr('Hapus')),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            if (b.status == BusinessStatus.approved && onEditNib != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  key: Key('nib-edit-${b.id}'),
                  onPressed: onEditNib,
                  child: Text(tr(b.nib == null ? 'Tambah NIB' : 'Ubah NIB')),
                ),
              ),
            ],
            if (b.status == BusinessStatus.approved && edit != null) ...[
              const SizedBox(height: 8),
              if (edit!.isPending)
                Text(
                  tr(
                    'Perubahan menunggu persetujuan admin. Data lama tetap '
                    'tampil sampai disetujui.',
                  ),
                  key: Key('edit-pending-${b.id}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Text(
                  trf('Perubahan ditolak: {0}', [
                    edit!.rejectReason ?? tr('tanpa alasan'),
                  ]),
                  key: Key('edit-rejected-${b.id}'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
            ],
            if (b.status == BusinessStatus.approved && onEdit != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (edit?.isPending == true && onCancelEdit != null)
                      TextButton(
                        key: Key('edit-cancel-${b.id}'),
                        onPressed: onCancelEdit,
                        child: Text(tr('Batalkan permintaan')),
                      ),
                    OutlinedButton(
                      key: Key('request-edit-${b.id}'),
                      onPressed: onEdit,
                      child: Text(
                        tr(
                          edit?.isPending == true
                              ? 'Ubah permintaan'
                              : 'Ajukan perubahan',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_canEdit && onEdit != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  key: Key('edit-${b.id}'),
                  onPressed: onEdit,
                  child: Text(
                    b.status == BusinessStatus.rejected
                        ? 'Edit and apply again'
                        : 'Edit',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
