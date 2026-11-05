import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../config/policy_config.dart';
import '../data/business_repository.dart';
import '../data/posting_text.dart';
import '../models/business.dart';
import '../util/friendly_error.dart';
import 'business_form_screen.dart';
import '../widgets/business_photo.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/error_view.dart';

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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Business>, List<BusinessUsage>)> _load() async {
    final mine = await _repo.mine(widget.ownerId);
    final usage = await _repo.usage(widget.ownerId);
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

  Future<void> _openForm([Business? existing]) async {
    if (existing == null && _activeCount >= kMaxBusinesses) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(_limitNote)));
      return;
    }
    await Navigator.of(context).push<Business>(
      MaterialPageRoute(
        builder: (_) => BusinessFormScreen(
          ownerId: widget.ownerId,
          repository: _repo,
          existing: existing,
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
      body: FutureBuilder<(List<Business>, List<BusinessUsage>)>(
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
                    [_limitNote],
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
                    _limitNote,
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
                  onDelete: () => _delete(b),
                );
              },
            ),
          );
        },
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
    this.onDelete,
  });

  final Business business;
  final BusinessUsage? usage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                  child: Text(
                    b.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: Chip(
                    key: Key('status-${b.id}'),
                    label: Text(
                      b.status.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
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
                  ? 'Approved band: ${b.approvedBand!.label}'
                  : 'Band you chose: ${b.requestedBand?.label ?? '-'} '
                        '(an admin sets the approved band)',
              style: theme.textTheme.bodyMedium,
            ),
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
