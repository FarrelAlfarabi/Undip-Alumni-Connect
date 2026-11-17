import '../nav/back_guard.dart';

import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../util/app_language.dart';
import '../widgets/error_view.dart';
import '../widgets/filter_dropdown.dart';

/// Admin > Kelola admin: who has admin access, add a member as admin, and
/// remove admin access. The database refuses non-admins, removing yourself,
/// the last admin and owner admins, and logs every change in Riwayat.
class AdminAdminsScreen extends StatefulWidget {
  const AdminAdminsScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminAdminsScreen> createState() => _AdminAdminsScreenState();
}

class _AdminAdminsScreenState extends State<AdminAdminsScreen> {
  late Future<List<AdminUser>> _future = _fetch();
  bool _busy = false;

  Future<List<AdminUser>> _fetch() => widget.repository.admins(widget.adminId);

  void _reload() => setState(() {
    _future = _fetch();
  });

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add() async {
    final picked = await Navigator.of(context).push<AdminMember>(
      AppRoute(
        builder: (_) => _PickMemberScreen(
          adminId: widget.adminId,
          repository: widget.repository,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Jadikan admin?')),
        content: Text(
          trf(
            '{0} bisa membuka menu Admin: melihat laporan, menyetujui bisnis, '
            'menangguhkan dan menghapus anggota.',
            [picked.name],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            key: const Key('confirm-add-admin'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Jadikan admin')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => widget.repository.addAdmin(widget.adminId, picked.id),
      trf('{0} sekarang admin.', [picked.name]),
    );
  }

  Future<void> _remove(AdminUser a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Hapus akses admin?')),
        content: Text(
          trf(
            '{0} tetap jadi anggota, tapi tidak bisa membuka menu Admin lagi.',
            [a.name],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            key: const Key('confirm-remove-admin'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Hapus akses')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => widget.repository.removeAdmin(widget.adminId, a.profileId),
      trf('Akses admin {0} dihapus.', [a.name]),
    );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _toast(done);
      _reload();
    } catch (e) {
      if (mounted) _toast(adminErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kelola admin'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-admin'),
        onPressed: _busy ? null : _add,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(tr('Tambah admin')),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FutureBuilder<List<AdminUser>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErrorView(
                    message: adminErrorMessage(snap.error!),
                    screen: 'Admin kelola admin',
                    error: snap.error,
                    onRetry: _reload,
                  );
                }
                final list = snap.data ?? const <AdminUser>[];
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          trf(
                            '{0} admin. Kamu tidak bisa menghapus dirimu '
                            'sendiri, admin terakhir, atau admin pemilik.',
                            [list.length],
                          ),
                          key: const Key('admins-count'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    final a = list[i - 1];
                    final self = a.profileId == widget.adminId;
                    final canRemove = !self && !a.isOwner && list.length > 1;
                    return ListTile(
                      key: Key('admin-${a.profileId}'),
                      title: Text(a.name),
                      subtitle: Text(
                        [
                          if (a.isOwner) tr('Pemilik'),
                          if (self) tr('Kamu'),
                          if ((a.email ?? '').isNotEmpty) a.email!,
                        ].join(' · '),
                      ),
                      trailing: canRemove
                          ? IconButton(
                              key: Key('remove-admin-${a.profileId}'),
                              tooltip: tr('Hapus akses admin'),
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _busy ? null : () => _remove(a),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Pick a verified, active member who is not an admin yet.
class _PickMemberScreen extends StatefulWidget {
  const _PickMemberScreen({required this.adminId, required this.repository});

  final String adminId;
  final AdminRepository repository;

  @override
  State<_PickMemberScreen> createState() => _PickMemberScreenState();
}

class _PickMemberScreenState extends State<_PickMemberScreen> {
  final _search = TextEditingController();
  late Future<List<AdminMember>> _future = widget.repository.searchMembers(
    widget.adminId,
    '',
  );

  void _retry() => setState(() {
    _future = widget.repository.searchMembers(widget.adminId, '');
  });

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pilih anggota'))),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FutureBuilder<List<AdminMember>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErrorView(
                    message: adminErrorMessage(snap.error!),
                    screen: 'Admin pilih anggota',
                    error: snap.error,
                    onRetry: _retry,
                  );
                }
                final q = _search.text.trim().toLowerCase();
                final list = (snap.data ?? const <AdminMember>[])
                    .where(
                      (m) =>
                          !m.isAdmin &&
                          !m.isSuspended &&
                          (m.verificationStatus == null ||
                              m.verificationStatus == 'verified') &&
                          (q.isEmpty ||
                              m.name.toLowerCase().contains(q) ||
                              (m.email ?? '').toLowerCase().contains(q)),
                    )
                    .toList();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClearableSearchField(
                        key: const Key('pick-search'),
                        controller: _search,
                        hintText: tr('Cari nama atau email...'),
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(tr('Tidak ada anggota yang cocok.')),
                            )
                          : ListView.separated(
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) => ListTile(
                                key: Key('pick-${list[i].id}'),
                                title: Text(list[i].name),
                                subtitle: Text(list[i].email ?? ''),
                                onTap: () => Navigator.of(context).pop(list[i]),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
