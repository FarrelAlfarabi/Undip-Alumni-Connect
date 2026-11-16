import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../data/admin_repository.dart';
import '../data/city_distances.dart';
import '../data/industries.dart';
import '../data/profile_fields.dart';
import '../widgets/admin_reason_dialog.dart';
import '../widgets/error_view.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/searchable_choice.dart';

/// Admin > Anggota: find a member, fix the basic fields a member can edit
/// themselves (jabatan, perusahaan, industri, kota, bio, LinkedIn), fix a
/// wrong NIM or jurusan, and suspend or lift a suspension. Same search and
/// filters as the Directory (name or company, major, year, industry, city),
/// plus email in the search and a status filter. All members, suspended ones
/// included, are loaded once and filtered here. Email and nama cannot be
/// edited and the database refuses them.
class AdminMembersScreen extends StatefulWidget {
  const AdminMembersScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  final String adminId;
  final AdminRepository repository;

  @override
  State<AdminMembersScreen> createState() => _AdminMembersScreenState();
}

class _AdminMembersScreenState extends State<AdminMembersScreen> {
  final _search = TextEditingController();
  final _industryText = TextEditingController();
  late Future<List<AdminMember>> _future;
  String _major = kAllFilter;
  String _year = kAllFilter;
  String _industry = kAllFilter;
  String _city = kAllFilter;
  String _status = kAllFilter;

  static const _statusActive = 'Aktif';
  static const _statusSuspended = 'Ditangguhkan';
  static const _statusAdmin = 'Admin';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _industryText.dispose();
    super.dispose();
  }

  void _load() {
    _future = widget.repository.searchMembers(widget.adminId, '');
  }

  bool get _active =>
      _search.text.isNotEmpty ||
      _major != kAllFilter ||
      _year != kAllFilter ||
      _industry != kAllFilter ||
      _city != kAllFilter ||
      _status != kAllFilter;

  void _clear() => setState(() {
    _search.clear();
    _industryText.clear();
    _major = _year = _industry = _city = _status = kAllFilter;
  });

  List<AdminMember> _filter(List<AdminMember> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((m) {
      if (_major != kAllFilter && m.major != _major) return false;
      if (_year != kAllFilter && '${m.graduationYear}' != _year) return false;
      if (_industry != kAllFilter && m.industry != _industry) return false;
      if (_city != kAllFilter && (m.city ?? '').trim() != _city) return false;
      if (_status == _statusActive && m.isSuspended) return false;
      if (_status == _statusSuspended && !m.isSuspended) return false;
      if (_status == _statusAdmin && !m.isAdmin) return false;
      if (q.isNotEmpty &&
          !m.name.toLowerCase().contains(q) &&
          !(m.company ?? '').toLowerCase().contains(q) &&
          !(m.email ?? '').toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _open(AdminMember m) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminMemberEditScreen(
          adminId: widget.adminId,
          repository: widget.repository,
          member: m,
        ),
      ),
    );
    if (saved == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Anggota'))),
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
                    screen: 'Admin anggota',
                    error: snap.error,
                    onRetry: () => setState(_load),
                  );
                }
                final all = snap.data ?? const <AdminMember>[];
                final list = _filter(all);
                List<String> distinct(String Function(AdminMember) f) =>
                    (all.map(f).where((v) => v.isNotEmpty).toSet().toList()
                      ..sort());
                final majors = [kAllFilter, ...distinct((m) => m.major ?? '')];
                final years = [
                  kAllFilter,
                  ...(all
                      .map((m) => m.graduationYear?.toString() ?? '')
                      .where((v) => v.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort((a, b) => b.compareTo(a))),
                ];
                final industries = distinct((m) => m.industry ?? '');
                final cities = [
                  kAllFilter,
                  ...distinct((m) => (m.city ?? '').trim()),
                ];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: ClearableSearchField(
                        key: const Key('members-search'),
                        controller: _search,
                        hintText: tr('Cari nama, perusahaan atau email...'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilterDropdown(
                              label: tr('Major'),
                              value: _major,
                              options: majors,
                              onChanged: (v) => setState(() => _major = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilterDropdown(
                              label: tr('Year'),
                              value: _year,
                              options: years,
                              onChanged: (v) => setState(() => _year = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SearchableChoice(
                              fieldKey: const Key('members-industry'),
                              label: tr('Industry'),
                              controller: _industryText,
                              options: industries,
                              selected: _industry == kAllFilter
                                  ? null
                                  : _industry,
                              enabled: true,
                              dense: true,
                              onSelected: (v) =>
                                  setState(() => _industry = v ?? kAllFilter),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilterDropdown(
                              label: tr('City'),
                              value: _city,
                              options: cities,
                              onChanged: (v) => setState(() => _city = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: FilterDropdown(
                        key: const Key('members-status'),
                        label: tr('Status'),
                        value: _status,
                        options: const [
                          kAllFilter,
                          _statusActive,
                          _statusSuspended,
                          _statusAdmin,
                        ],
                        onChanged: (v) => setState(() => _status = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _active
                                  ? trf('{0} dari {1} anggota', [
                                      list.length,
                                      all.length,
                                    ])
                                  : trf('{0} anggota', [all.length]),
                              key: const Key('members-count'),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          ClearFiltersButton(
                            active: _active,
                            onPressed: _clear,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(tr('Tidak ada anggota yang cocok.')),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) => ListTile(
                                key: Key('member-${list[i].id}'),
                                title: Text(list[i].name),
                                subtitle: Text(
                                  [
                                    if (list[i].major != null) list[i].major!,
                                    if (list[i].graduationYear != null)
                                      '${list[i].graduationYear}',
                                    if ((list[i].company ?? '').isNotEmpty)
                                      list[i].company!,
                                  ].join(' · '),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (list[i].isAdmin)
                                      _StatusTag(
                                        key: Key('tag-admin-${list[i].id}'),
                                        text: tr('Admin'),
                                      ),
                                    if (list[i].isSuspended)
                                      _StatusTag(
                                        key: Key('tag-suspended-${list[i].id}'),
                                        text: tr('Ditangguhkan'),
                                        error: true,
                                      ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () => _open(list[i]),
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

/// Edit form for one member. Pops true after a save.
class AdminMemberEditScreen extends StatefulWidget {
  const AdminMemberEditScreen({
    super.key,
    required this.adminId,
    required this.repository,
    required this.member,
  });

  final String adminId;
  final AdminRepository repository;
  final AdminMember member;

  @override
  State<AdminMemberEditScreen> createState() => _AdminMemberEditScreenState();
}

class _AdminMemberEditScreenState extends State<AdminMemberEditScreen> {
  late final _role = TextEditingController(text: widget.member.role ?? '');
  late final _company = TextEditingController(
    text: widget.member.company ?? '',
  );
  late final _bio = TextEditingController(text: widget.member.bio ?? '');
  late final _linkedin = TextEditingController(
    text: widget.member.linkedinUrl ?? '',
  );
  late final _industryText = TextEditingController(
    text: widget.member.industry ?? '',
  );
  late final _cityText = TextEditingController(text: widget.member.city ?? '');
  late String? _industry = _clean(widget.member.industry);
  late String? _city = _clean(widget.member.city);
  bool _saving = false;
  String? _error;

  static String? _clean(String? v) {
    final s = v?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  void dispose() {
    for (final c in [
      _role,
      _company,
      _bio,
      _linkedin,
      _industryText,
      _cityText,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Only the fields that differ from what was loaded.
  Map<String, String?> _changes() {
    final m = widget.member;
    final out = <String, String?>{};
    void add(String key, String? old, String? now) {
      if ((old ?? '').trim() != (now ?? '').trim()) out[key] = now;
    }

    add('current_role', m.role, _role.text);
    add('company', m.company, _company.text);
    add('industry', m.industry, _industry);
    add('city', m.city, _city);
    add('bio', m.bio, _bio.text);
    add('linkedin_url', m.linkedinUrl, _linkedin.text);
    return out;
  }

  Future<void> _save() async {
    final changes = _changes();
    if (changes.isEmpty) {
      setState(() => _error = tr('Belum ada yang diubah.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateMember(
        widget.adminId,
        widget.member.id,
        changes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Data anggota tersimpan.'))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final invalid =
          e is AdminException && e.code == AdminErrorCode.invalidInput;
      setState(() {
        _saving = false;
        _error = invalid
            ? tr(
                'Isian tidak valid. Bio paling banyak 200 huruf, dan tautan '
                'harus dari linkedin.com.',
              )
            : adminErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return Scaffold(
      appBar: AppBar(title: Text(m.name)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  trf(
                    'Kamu mengubah data {0}. Hanya isian yang bisa diubah '
                    'anggota sendiri yang tampil di sini.',
                    [m.name],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('member-role'),
                  controller: _role,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: tr('Jabatan'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('member-company'),
                  controller: _company,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: tr('Perusahaan'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SearchableChoice(
                  fieldKey: const Key('member-industry'),
                  label: tr('Industri'),
                  controller: _industryText,
                  options: kIndustries,
                  selected: _industry,
                  enabled: !_saving,
                  onSelected: (v) => setState(() => _industry = v),
                ),
                const SizedBox(height: 16),
                SearchableChoice(
                  fieldKey: const Key('member-city'),
                  label: tr('Kota'),
                  controller: _cityText,
                  options: kNearbyCities,
                  selected: _city,
                  enabled: !_saving,
                  onSelected: (v) => setState(() => _city = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('member-bio'),
                  controller: _bio,
                  enabled: !_saving,
                  maxLines: 3,
                  inputFormatters: const [CodePointLimit(kBioMax)],
                  decoration: InputDecoration(
                    labelText: tr('Bio'),
                    helperText: tr(
                      'Kosongkan untuk menghapus. Paling banyak 200 huruf.',
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('member-linkedin'),
                  controller: _linkedin,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'LinkedIn',
                    helperText: tr(
                      'Tautan linkedin.com. Kosongkan untuk menghapus.',
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const Key('member-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('member-save'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(tr('Simpan')),
                ),
                const SizedBox(height: 32),
                Text(
                  tr('Akun'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (m.isSuspended)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      trf('Ditangguhkan. Alasan: {0}', [
                        m.suspendedReason ?? '-',
                      ]),
                      key: const Key('member-suspended-note'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ListTile(
                  key: const Key('member-identity'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(tr('Perbaiki NIM atau jurusan')),
                  subtitle: Text(tr('Untuk data impor yang salah')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _saving ? null : _openIdentity,
                ),
                if (_canSuspend)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      key: const Key('member-suspend'),
                      style: m.isSuspended
                          ? null
                          : OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .error,
                            ),
                      icon: Icon(
                        m.isSuspended
                            ? Icons.lock_open_outlined
                            : Icons.block_outlined,
                      ),
                      label: Text(
                        m.isSuspended
                            ? tr('Aktifkan lagi')
                            : tr('Tangguhkan anggota'),
                      ),
                      onPressed: _saving ? null : _toggleSuspend,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tr('Admin dan akunmu sendiri tidak bisa ditangguhkan.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSuspend =>
      !widget.member.isAdmin && widget.member.id != widget.adminId;

  Future<void> _openIdentity() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminMemberIdentityScreen(
          adminId: widget.adminId,
          repository: widget.repository,
          member: widget.member,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _toggleSuspend() async {
    final m = widget.member;
    final messenger = ScaffoldMessenger.of(context);
    String? reason;
    if (m.isSuspended) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Aktifkan lagi anggota ini?')),
          content: Text(
            trf('{0} bisa masuk lagi dan tampil di Directory.', [m.name]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('Batal')),
            ),
            FilledButton(
              key: const Key('confirm-unsuspend'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('Aktifkan')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      reason = await askAdminReason(
        context,
        title: tr('Tangguhkan anggota ini?'),
        body: trf(
          '{0} tidak bisa masuk dan hilang dari Directory sampai kamu '
          'mengaktifkannya lagi. Bisnis dan postingannya tetap ada: '
          'sembunyikan terpisah bila perlu.',
          [m.name],
        ),
        action: tr('Tangguhkan'),
        destructive: true,
      );
      if (reason == null) return;
    }
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.setMemberSuspended(
        widget.adminId,
        m.id,
        suspend: !m.isSuspended,
        reason: reason,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            m.isSuspended
                ? tr('Anggota aktif lagi.')
                : tr('Anggota ditangguhkan.'),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = adminErrorMessage(e);
      });
    }
  }
}

/// Small coloured tag in the member list (Admin, Ditangguhkan).
class _StatusTag extends StatelessWidget {
  const _StatusTag({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: error ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Fix a wrong NIM or jurusan for one member. Loads the current values from
/// the database (NIM is not in the member list). Pops true after a save.
class AdminMemberIdentityScreen extends StatefulWidget {
  const AdminMemberIdentityScreen({
    super.key,
    required this.adminId,
    required this.repository,
    required this.member,
  });

  final String adminId;
  final AdminRepository repository;
  final AdminMember member;

  @override
  State<AdminMemberIdentityScreen> createState() =>
      _AdminMemberIdentityScreenState();
}

class _AdminMemberIdentityScreenState extends State<AdminMemberIdentityScreen> {
  final _nim = TextEditingController();
  final _majorText = TextEditingController();
  String? _major;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nim.dispose();
    _majorText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.repository.memberIdentity(
        widget.adminId,
        widget.member.id,
      );
      if (!mounted) return;
      setState(() {
        _nim.text = r.nim ?? '';
        _major = r.major;
        _majorText.text = r.major ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = adminErrorMessage(e);
      });
    }
  }

  Future<void> _save() async {
    final nim = _nim.text.trim().toUpperCase();
    final major = (_major ?? '').trim();
    if (!RegExp(r'^[A-Z0-9-]{5,30}$').hasMatch(nim) || major.isEmpty) {
      setState(
        () => _error = tr(
          'NIM 5 sampai 30 huruf atau angka, dan jurusan wajib dipilih.',
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.setMemberIdentity(
        widget.adminId,
        widget.member.id,
        nim: nim,
        major: major,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('NIM dan jurusan tersimpan.'))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = adminErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final majors = {...kAdminMajors, ?_major}.toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('NIM dan jurusan'))),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        trf(
                          'Perbaiki data alumni {0} bila hasil impor salah. '
                          'NIM hanya terlihat oleh admin.',
                          [widget.member.name],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('identity-nim'),
                        controller: _nim,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: tr('NIM'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SearchableChoice(
                        fieldKey: const Key('identity-major'),
                        label: tr('Jurusan'),
                        controller: _majorText,
                        options: majors,
                        selected: _major,
                        enabled: !_saving,
                        onSelected: (v) => setState(() => _major = v),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          key: const Key('identity-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('identity-save'),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(tr('Simpan')),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The FEB jurusan the alumni list uses.
const kAdminMajors = [
  'Akuntansi',
  'Ilmu Ekonomi dan Studi Pembangunan',
  'Manajemen',
];
