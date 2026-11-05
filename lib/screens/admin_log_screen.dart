import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';

/// Admin Riwayat: the last 200 admin actions (who did what, when).
class AdminLogScreen extends StatefulWidget {
  const AdminLogScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminLogScreen> createState() => _AdminLogScreenState();
}

class _AdminLogScreenState extends State<AdminLogScreen> {
  late Future<List<AdminLogEntry>> _future = widget.repository.actionLog(
    widget.adminId,
  );

  void _reload() => setState(() {
    _future = widget.repository.actionLog(widget.adminId);
  });

  static String _when(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat admin')),
      body: FutureBuilder<List<AdminLogEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              message: friendlyLoadError('riwayat', snap.error),
              screen: 'Admin log',
              error: snap.error,
              onRetry: _reload,
            );
          }
          final items = snap.data ?? const <AdminLogEntry>[];
          if (items.isEmpty) {
            return const Center(child: Text('Belum ada riwayat.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = items[i];
                return ListTile(
                  key: Key('log-$i'),
                  title: Text(e.action),
                  subtitle: Text(
                    [
                      e.adminName,
                      if (e.targetType != null) e.targetType!,
                      if (e.detail != null && e.detail!.isNotEmpty) e.detail!,
                    ].join(' · '),
                  ),
                  trailing: Text(
                    _when(e.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
