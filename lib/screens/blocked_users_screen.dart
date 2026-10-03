import 'package:flutter/material.dart';

import '../data/block_list.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';

/// People I blocked, each with an Unblock button.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({
    super.key,
    required this.currentUserId,
    this.repository,
    this.blockList,
  });

  final String currentUserId;
  final BlockRepository? repository;
  final BlockList? blockList;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final BlockRepository _repo = widget.repository ?? BlockRepository();
  late Future<List<BlockedPerson>> _future;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _repo.list(widget.currentUserId);
  }

  void _reload() => setState(() {
    _future = _repo.list(widget.currentUserId);
  });

  Future<void> _unblock(BlockedPerson p) async {
    setState(() => _busy.add(p.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await (widget.blockList ?? BlockList.shared).unblock(
        widget.currentUserId,
        p.id,
      );
      messenger.showSnackBar(SnackBar(content: Text('Unblocked ${p.name}.')));
      _busy.remove(p.id);
      if (mounted) _reload();
    } catch (e) {
      showErrorSnackBarOn(
        messenger,
        message: friendlyError(e),
        screen: 'Blocked users',
        error: e,
      );
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: FutureBuilder<List<BlockedPerson>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              message: friendlyLoadError('blocked users', snap.error),
              screen: 'Blocked users',
              error: snap.error,
              onRetry: _reload,
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You have not blocked anyone.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = items[i];
              return ListTile(
                title: Text(p.name),
                trailing: OutlinedButton(
                  key: Key('unblock-${p.id}'),
                  onPressed: _busy.contains(p.id) ? null : () => _unblock(p),
                  child: const Text('Unblock'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
