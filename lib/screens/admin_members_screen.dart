import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../data/admin_repository.dart';
import '../data/city_distances.dart';
import '../data/industries.dart';
import '../data/profile_fields.dart';
import '../widgets/error_view.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/searchable_choice.dart';

/// Admin > Ubah profil anggota: find a member and fix the basic fields a
/// member can edit themselves (jabatan, perusahaan, industri, kota, bio,
/// LinkedIn). Same search and filters as the Directory (name or company,
/// major, year, industry, city), plus email in the search. All members are
/// loaded once and filtered here. NIM, email, nama and status cannot be
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
      _city != kAllFilter;

  void _clear() => setState(() {
    _search.clear();
    _industryText.clear();
    _major = _year = _industry = _city = kAllFilter;
  });

  List<AdminMember> _filter(List<AdminMember> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((m) {
      if (_major != kAllFilter && m.major != _major) return false;
      if (_year != kAllFilter && '${m.graduationYear}' != _year) return false;
      if (_industry != kAllFilter && m.industry != _industry) return false;
      if (_city != kAllFilter && (m.city ?? '').trim() != _city) return false;
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
      appBar: AppBar(title: Text(tr('Ubah profil anggota'))),
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
                    screen: 'Ubah profil anggota',
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
                                trailing: const Icon(Icons.chevron_right),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
