import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../models/business_edit_request.dart';
import '../util/app_language.dart';
import '../util/friendly_error.dart';
import '../widgets/app_photo.dart';
import '../widgets/error_view.dart';
import '../widgets/responsive_page.dart';

/// Admin: change requests for approved businesses. Each card shows what the
/// business has now next to what the owner asks for. Approve puts the new
/// values live; reject needs a reason and the old version stays.
class AdminBusinessEditsScreen extends StatefulWidget {
  const AdminBusinessEditsScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminBusinessEditsScreen> createState() =>
      _AdminBusinessEditsScreenState();
}

class _AdminBusinessEditsScreenState extends State<AdminBusinessEditsScreen> {
  late Future<List<BusinessEditRequest>> _future;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _future = widget.repository.businessEdits(widget.adminId);
  }

  void _reload() => setState(() {
    _future = widget.repository.businessEdits(widget.adminId);
  });

  Future<void> _decide(
    BusinessEditRequest r, {
    required bool approve,
    String? reason,
  }) async {
    setState(() => _busy.add(r.id));
    try {
      await widget.repository.decideBusinessEdit(
        widget.adminId,
        r.id,
        approve,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? tr('Perubahan disetujui dan sudah tampil.')
                : tr('Perubahan ditolak. Data lama tetap tampil.'),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          message: adminErrorMessage(e),
          screen: 'Admin business edits',
          error: e,
        );
      }
    }
    if (!mounted) return;
    _busy.remove(r.id);
    _reload();
  }

  Future<void> _reject(BusinessEditRequest r) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(tr('Tolak perubahan')),
            content: TextField(
              key: const Key('edit-reject-reason'),
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: tr('Alasan (dikirim ke pemilik)'),
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('Batal')),
              ),
              FilledButton(
                key: const Key('edit-reject-confirm'),
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) {
                    setLocal(() => error = tr('Alasan wajib diisi'));
                    return;
                  }
                  Navigator.of(ctx).pop(t);
                },
                child: Text(tr('Tolak')),
              ),
            ],
          ),
        );
      },
    );
    if (reason == null || !mounted) return;
    await _decide(r, approve: false, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Perubahan bisnis'))),
      body: ResponsivePage(
        builder: (_, _) => SafeArea(
          top: false,
          child: FutureBuilder<List<BusinessEditRequest>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErrorView(
                  message: friendlyLoadError('perubahan bisnis', snap.error),
                  screen: 'Admin business edits',
                  error: snap.error,
                  onRetry: _reload,
                );
              }
              final items = snap.data ?? const <BusinessEditRequest>[];
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    tr('Tidak ada perubahan yang menunggu.'),
                    key: const Key('edits-empty'),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _EditCard(
                  request: items[i],
                  busy: _busy.contains(items[i].id),
                  onApprove: () => _decide(items[i], approve: true),
                  onReject: () => _reject(items[i]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EditCard extends StatelessWidget {
  const _EditCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final BusinessEditRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final changes = r.changes();
    final photo = changes.where((c) => c.field == 'photo').isNotEmpty;
    final nib = changes.where((c) => c.field == 'nib').isNotEmpty;
    return Card(
      key: Key('edit-${r.id}'),
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
            Text(
              r.current?.name ?? r.proposed.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              trf('Pemilik: {0}', [r.ownerName ?? 'Alumni']),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Sekarang'),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('Diajukan'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            for (final c in changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.label, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: c.field == 'photo'
                              ? _thumb(r.current?.photoUrl)
                              : Text(c.oldText, key: Key('old-${c.field}')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: c.field == 'photo'
                              ? _thumb(r.proposed.photoUrl)
                              : Text(
                                  c.newText,
                                  key: Key('new-${c.field}'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (photo || changes.isEmpty) const SizedBox.shrink(),
            if (nib) ...[
              Text(
                r.currentNibVerified
                    ? tr(
                        'NIB berubah: tanda centang biru dicabut sampai NIB '
                        'baru dicek lagi di Businesses.',
                      )
                    : tr('NIB berubah: cek NIB baru di Businesses.'),
                key: const Key('nib-change-note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  key: Key('edit-reject-${r.id}'),
                  onPressed: busy ? null : onReject,
                  child: Text(tr('Tolak')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: Key('edit-approve-${r.id}'),
                  onPressed: busy ? null : onApprove,
                  child: Text(tr('Setujui')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String? url) => (url == null || url.isEmpty)
      ? Text(tr('(kosong)'))
      : AppPhoto(url: url, semanticLabel: tr('Foto bisnis'));
}
