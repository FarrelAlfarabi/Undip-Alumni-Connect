import 'package:flutter/material.dart';

import '../config/policy_config.dart';
import '../data/business_repository.dart';
import '../data/posting_text.dart';
import '../models/business.dart';
import '../util/friendly_error.dart';
import 'business_form_screen.dart';
import '../widgets/error_view.dart';

const String _limitNote =
    'You can own up to $kMaxBusinesses businesses. To add more, email '
    '$kContactEmail.';

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
      appBar: AppBar(title: const Text('My businesses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Register a business'),
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You have not registered a business yet. Register one so '
                  'other alumni can find it.\n\n$_limitNote',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
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
              );
            },
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
  });

  final Business business;
  final BusinessUsage? usage;
  final VoidCallback? onEdit;

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
            if (b.isHidden) ...[
              const SizedBox(height: 8),
              Text(
                'Hidden by an admin${b.hiddenReason != null ? ': ${b.hiddenReason}' : ''}. '
                'Other people cannot see this business or its products.',
                key: Key('hidden-${b.id}'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (b.status == BusinessStatus.rejected) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${b.rejectionReason ?? 'not given'}',
                key: Key('reason-${b.id}'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (b.status == BusinessStatus.suspended) ...[
              const SizedBox(height: 8),
              const Text(
                'This business is suspended. Please contact an admin.',
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
