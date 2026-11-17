import 'dart:async';

import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../data/admin_repository.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import '../widgets/filter_dropdown.dart';

/// Admin Riwayat: who did what, when. Search (action, detail, admin name),
/// filter by kind and by period. The database does the filtering, so older
/// rows are found too (300 rows at most per search).
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

/// Kinds in the filter: label and the action prefix sent to the database.
const _kinds = <String, String?>{
  kAllFilter: null,
  'Anggota': 'member_',
  'Kelola admin': 'admin_',
  'Ubah profil': 'edit_profile',
  'Bisnis': 'business_',
  'Jobs': 'job_',
  'Marketplace': 'listing_',
  'Laporan': 'report_',
  'Pengumuman': 'announcement_',
  'Sponsor': 'sponsor_',
  'Urutan Home': 'home_order',
};

const _periods = <String, int?>{
  kAllFilter: null,
  '24 jam terakhir': 1,
  '7 hari': 7,
  '30 hari': 30,
};

/// Plain Indonesian name for an action code. Unknown codes are shown as they
/// are, so nothing is ever hidden.
String adminActionLabel(String action) {
  const exact = {
    'member_suspend': 'Anggota ditangguhkan',
    'member_unsuspend': 'Anggota diaktifkan lagi',
    'member_fix_major': 'Jurusan diperbaiki',
    'member_remove': 'Anggota dan datanya dihapus',
    'admin_add': 'Admin ditambah',
    'admin_remove': 'Akses admin dihapus',
    'edit_profile': 'Profil anggota diubah',
    'job_delete': 'Lowongan dihapus',
    'job_hide': 'Lowongan ditangguhkan',
    'job_restore': 'Lowongan ditampilkan lagi',
    'listing_delete': 'Produk dihapus',
    'business_approve': 'Bisnis disetujui',
    'business_reject': 'Bisnis ditolak',
    'business_suspend': 'Bisnis ditangguhkan',
    'business_restore': 'Bisnis dipulihkan',
    'business_nib_verified': 'NIB ditandai terverifikasi',
    'business_nib_unverified': 'Verifikasi NIB dicabut',
    'announcement_create': 'Pengumuman dibuat',
    'announcement_edit': 'Pengumuman diubah',
    'announcement_delete': 'Pengumuman dihapus',
    'sponsor_save': 'Sponsor disimpan',
    'sponsor_delete': 'Sponsor dihapus',
    'home_order': 'Urutan Home diubah',
  };
  final hit = exact[action];
  if (hit != null) return tr(hit);
  const reports = {
    'report_dismiss': 'Laporan diabaikan',
    'report_reopen': 'Laporan dibuka lagi',
    'report_hide': 'Laporan: konten ditangguhkan',
    'report_restore': 'Laporan: konten ditampilkan lagi',
    'report_remove': 'Laporan: konten dihapus',
    'report_delete': 'Laporan: konten dihapus',
  };
  final rep = reports[action];
  if (rep != null) return tr(rep);
  if (action.startsWith('report_')) return tr('Laporan diproses');
  return action;
}

class _AdminLogScreenState extends State<AdminLogScreen> {
  static const _limit = 300;
  final _search = TextEditingController();
  Timer? _debounce;
  String _kind = kAllFilter;
  String _period = kAllFilter;
  late Future<List<AdminLogEntry>> _future = _fetch();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<List<AdminLogEntry>> _fetch() {
    final days = _periods[_period];
    return widget.repository.searchLog(
      widget.adminId,
      search: _search.text,
      actionPrefix: _kinds[_kind],
      limit: _limit,
      since: days == null
          ? null
          : DateTime.now().subtract(Duration(days: days)),
    );
  }

  void _reload() => setState(() {
    _future = _fetch();
  });

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  bool get _active =>
      _search.text.isNotEmpty || _kind != kAllFilter || _period != kAllFilter;

  void _clear() {
    _search.clear();
    _kind = _period = kAllFilter;
    _reload();
  }

  /// "Anggota", "Bisnis", "Lowongan" ... for the line that names who or what
  /// the action was done to.
  static String _targetWord(AdminLogEntry e) => switch (e.targetType) {
    'profile' => tr('Anggota'),
    'business' => tr('Bisnis'),
    'job' => tr('Lowongan'),
    'listing' => tr('Produk'),
    _ => tr('Untuk'),
  };

  static String _when(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Riwayat admin'))),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    key: const Key('log-search'),
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _reload(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: tr('Cari aksi, alasan atau nama admin...'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilterDropdown(
                          key: ValueKey('log-kind:$_kind'),
                          label: tr('Jenis'),
                          value: _kind,
                          options: _kinds.keys.toList(),
                          onChanged: (v) {
                            _kind = v;
                            _reload();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilterDropdown(
                          key: ValueKey('log-period:$_period'),
                          label: tr('Waktu'),
                          value: _period,
                          options: _periods.keys.toList(),
                          onChanged: (v) {
                            _period = v;
                            _reload();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ClearFiltersButton(
                      active: _active,
                      onPressed: _clear,
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<AdminLogEntry>>(
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
                        return Center(
                          child: Text(
                            _active
                                ? tr('Tidak ada riwayat yang cocok.')
                                : tr('Belum ada riwayat.'),
                            key: const Key('log-empty'),
                          ),
                        );
                      }
                      // The search asks for 300 rows at most. Say so when the
                      // limit was reached, so nobody thinks that is everything.
                      final capped = items.length >= _limit;
                      return RefreshIndicator(
                        onRefresh: () async => _reload(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: items.length + (capped ? 1 : 0),
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            if (i == items.length) {
                              return Padding(
                                key: const Key('log-capped'),
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  trf(
                                    'Menampilkan {0} terbaru. Persempit '
                                    'pencarian untuk melihat yang lebih lama.',
                                    [_limit],
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            }
                            final e = items[i];
                            return ListTile(
                              key: Key('log-$i'),
                              isThreeLine: (e.targetLabel ?? '').isNotEmpty,
                              title: Text(adminActionLabel(e.action)),
                              subtitle: Text(
                                [
                                  trf('Oleh: {0}', [e.adminName]),
                                  if ((e.targetLabel ?? '').isNotEmpty)
                                    trf('{0}: {1}', [
                                      _targetWord(e),
                                      e.targetLabel,
                                    ]),
                                  if (e.detail != null && e.detail!.isNotEmpty)
                                    e.detail!,
                                ].join('\n'),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
