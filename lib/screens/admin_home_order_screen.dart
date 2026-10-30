import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../data/home_repository.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import '../widgets/filter_dropdown.dart';

/// Admin > Home order: choose which products and jobs Home shows first and in
/// what order. Editorial only. Every move saves the whole pinned list in one
/// call, so a failure cannot leave a half-changed order.
class AdminHomeOrderScreen extends StatefulWidget {
  const AdminHomeOrderScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminHomeOrderScreen> createState() => _AdminHomeOrderScreenState();
}

class _AdminHomeOrderScreenState extends State<AdminHomeOrderScreen> {
  static const _products = 'listing';
  static const _jobs = 'job';

  final _search = TextEditingController();
  String _kind = _products;
  List<HomeOrderItem>? _items;
  Object? _loadError;
  String? _saveError;
  bool _busy = false;

  bool get _isProducts => _kind == _products;
  int get _limit => _isProducts ? kHomeListingLimit : kHomeJobLimit;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final kind = _kind;
    try {
      final items = await widget.repository.homeOrderItems(
        widget.adminId,
        kind,
      );
      if (!mounted || kind != _kind) return;
      setState(() {
        _items = items;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted || kind != _kind) return;
      setState(() {
        _items = null;
        _loadError = e;
      });
    }
  }

  void _switchKind(String kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _items = null;
      _loadError = null;
      _saveError = null;
      _search.clear();
    });
    _load();
  }

  List<HomeOrderItem> get _pinned =>
      (_items ?? const <HomeOrderItem>[]).where((i) => i.rank != null).toList()
        ..sort((a, b) => a.rank!.compareTo(b.rank!));

  /// How many pinned items Home would really show.
  int get _shownPinned => _pinned.where((i) => i.isShown).length;

  bool get _full => _shownPinned >= _limit;

  Future<void> _save(List<String> ids) async {
    setState(() {
      _busy = true;
      _saveError = null;
    });
    try {
      await widget.repository.setHomeOrder(
        adminId: widget.adminId,
        kind: _kind,
        ids: ids,
      );
    } catch (e) {
      _saveError = adminErrorMessage(e);
    }
    // Always reload, so the list never stays half shown.
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  List<String> get _pinnedIds => [for (final i in _pinned) i.id];

  void _pin(HomeOrderItem item) => _save([..._pinnedIds, item.id]);

  void _unpin(HomeOrderItem item) => _save([
    for (final id in _pinnedIds)
      if (id != item.id) id,
  ]);

  void _move(HomeOrderItem item, int by) {
    final ids = _pinnedIds;
    final from = ids.indexOf(item.id);
    final to = from + by;
    if (from < 0 || to < 0 || to >= ids.length) return;
    ids.removeAt(from);
    ids.insert(to, item.id);
    _save(ids);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home order')),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('home-order-products'),
                  label: const Text('Products'),
                  selected: _isProducts,
                  onSelected: _busy ? null : (_) => _switchKind(_products),
                ),
                ChoiceChip(
                  key: const Key('home-order-jobs'),
                  label: const Text('Jobs'),
                  selected: !_isProducts,
                  onSelected: _busy ? null : (_) => _switchKind(_jobs),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tampil di Home: $kHomeListingLimit produk, '
                '$kHomeJobLimit lowongan. Yang dipin tampil dulu, urutan 1 '
                'paling depan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loadError != null) {
      return ErrorView(
        message: _loadError is AdminException
            ? adminErrorMessage(_loadError!)
            : friendlyLoadError('Home order', _loadError),
        screen: 'Admin Home order',
        error: _loadError,
        onRetry: _load,
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final pinned = _pinned;
    final q = _search.text.trim().toLowerCase();
    final others = items.where((i) => i.rank == null).where((i) {
      if (q.isEmpty) return true;
      return '${i.title} ${i.ownerName ?? ''}'.toLowerCase().contains(q);
    }).toList();

    if (items.isEmpty) {
      return Center(
        child: Text(
          _isProducts
              ? 'Belum ada produk yang disetujui.'
              : 'Belum ada lowongan aktif.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_saveError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _saveError!,
              key: const Key('home-order-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        Text('Dipin', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (pinned.isEmpty)
          Text(
            'Belum ada yang dipin. Home menampilkan yang terbaru.',
            style: theme.textTheme.bodySmall,
          ),
        for (var i = 0; i < pinned.length; i++)
          _pinnedRow(theme, pinned[i], i, pinned.length),
        const SizedBox(height: 20),
        Text('Belum dipin', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (_full)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Home sudah penuh. Lepas satu pin dulu.',
              key: const Key('home-order-full'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ClearableSearchField(
          key: const Key('home-order-search'),
          controller: _search,
          hintText: _isProducts ? 'Cari produk...' : 'Cari lowongan...',
        ),
        const SizedBox(height: 8),
        if (others.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              q.isEmpty ? 'Semua sudah dipin.' : 'Tidak ada yang cocok.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final item in others) _otherRow(theme, item),
      ],
    );
  }

  Widget _pinnedRow(ThemeData theme, HomeOrderItem item, int index, int count) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              child: Text('${index + 1}', style: theme.textTheme.labelMedium),
            ),
            const SizedBox(width: 12),
            Expanded(child: _titleBlock(theme, item, notShown: !item.isShown)),
            IconButton(
              key: Key('home-order-up-${item.id}'),
              tooltip: 'Naikkan',
              icon: const Icon(Icons.arrow_upward),
              onPressed: _busy || index == 0 ? null : () => _move(item, -1),
            ),
            IconButton(
              key: Key('home-order-down-${item.id}'),
              tooltip: 'Turunkan',
              icon: const Icon(Icons.arrow_downward),
              onPressed: _busy || index == count - 1
                  ? null
                  : () => _move(item, 1),
            ),
            TextButton(
              key: Key('home-order-unpin-${item.id}'),
              onPressed: _busy ? null : () => _unpin(item),
              child: const Text('Lepas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otherRow(ThemeData theme, HomeOrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: _titleBlock(theme, item)),
          FilledButton.tonal(
            key: Key('home-order-pin-${item.id}'),
            onPressed: _busy || _full ? null : () => _pin(item),
            child: const Text('Pin'),
          ),
        ],
      ),
    );
  }

  Widget _titleBlock(
    ThemeData theme,
    HomeOrderItem item, {
    bool notShown = false,
  }) {
    final label = item.statusLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        if ((item.ownerName ?? '').isNotEmpty)
          Text(item.ownerName!, style: theme.textTheme.bodySmall),
        if (notShown)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              children: [
                if (label != null) _tag(theme, label),
                _tag(theme, 'Tidak tampil di Home'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tag(ThemeData theme, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: theme.textTheme.bodySmall),
  );
}
