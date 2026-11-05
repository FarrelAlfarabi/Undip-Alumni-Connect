import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../util/safe_url.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/avatar_repository.dart';
import '../data/blocked_filter.dart';
import '../data/profile_columns.dart';
import '../lock/lock_store.dart';
import '../widgets/linkedin_logo.dart';
import '../widgets/avatar.dart';
import '../widgets/error_view.dart';
import '../util/friendly_error.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/searchable_choice.dart';
import 'profile_detail_screen.dart';

/// Most alumni rows one load brings in, so the list does not grow without
/// bound as people join. Rows are ordered by name, so past this many the last
/// names are cut off until search is done on the server.
const int kDirectoryMaxRows = 500;

/// Where this person works. `company` is the field people edit now; rows
/// saved before the two fields were merged may only have `current_employer`.
String? _employerOf(Map<String, dynamic> p) {
  for (final k in ['company', 'current_employer']) {
    final v = (p[k] as String?)?.trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

/// Searchable alumni directory: filter by major, graduation year, and
/// industry, plus free-text search on name/company. Demo scope: fetches
/// verified alumni_profiles rows once (at most [kDirectoryMaxRows]) and
/// filters client-side — fine for the beta, not meant to scale past it.
///
/// Faculty is not a filter here: this app is scoped to a single faculty
/// (Fakultas Ekonomika dan Bisnis / Ikafe), not campus-wide UNDIP, so
/// "faculty" carries no useful signal — major is the meaningful axis.
///
/// Always embedded as a tab inside AlumniScreen (no own AppBar/Scaffold) —
/// see alumni_screen.dart.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({
    super.key,
    required this.currentUser,
    this.fetchAlumni,
    this.flagStore,
    this.openLink,
  });

  /// Opens a web link. Injectable for tests; defaults to the system browser.
  final Future<bool> Function(String? url)? openLink;

  /// Remembers on this device that the own-year default was already used.
  /// Injectable for tests; defaults to secure storage.
  final LockStore? flagStore;

  /// Injectable for tests; defaults to the Supabase query.
  final Future<List<Map<String, dynamic>>> Function()? fetchAlumni;

  /// The verified alumnus browsing the directory, as a shared notifier —
  /// threaded through (same reference, not a copy) to ProfileDetailScreen.
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  final _searchController = TextEditingController();
  final _industryController = TextEditingController(text: kAllFilter);
  String _major = kAllFilter;
  String _year = kAllFilter;
  String _industry = kAllFilter;
  String _city = kAllFilter;

  @override
  void initState() {
    super.initState();
    _future = _fetchAlumni();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _industryController.dispose();
    super.dispose();
  }

  static const _yearDefaultKey = 'directory_year_default_used';

  /// Opens on the user's own graduation year, but only the very first time
  /// this device opens the directory. Later visits start with no filter. If
  /// the flag cannot be read, no default is applied. Skipped when the profile
  /// has no year, or nobody in the list shares it.
  Future<List<Map<String, dynamic>>> _withDefaultYear(
    List<Map<String, dynamic>> rows,
  ) async {
    final store = widget.flagStore ?? const SecureLockStore();
    try {
      if (await store.read(_yearDefaultKey) != null) return rows;
      await store.write(_yearDefaultKey, '1');
    } catch (_) {
      return rows;
    }
    final own = widget.currentUser.value['graduation_year']?.toString();
    if (own != null &&
        _year == kAllFilter &&
        rows.any((p) => p['graduation_year']?.toString() == own)) {
      _year = own;
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> _fetchAlumni() async {
    if (widget.fetchAlumni != null) {
      return _withDefaultYear(
        await withoutBlockedProfiles(await widget.fetchAlumni!()),
      );
    }
    final rows = await Supabase.instance.client
        .from('alumni_profiles')
        .select(kProfileColumns)
        .eq('verification_status', 'verified')
        .order('name', ascending: true)
        .limit(kDirectoryMaxRows);
    return _withDefaultYear(
      await withoutBlockedProfiles(
        AvatarRepository.withAvatars(
          List<Map<String, dynamic>>.from(rows as List),
          await AvatarRepository().urlsById(),
        ),
      ),
    );
  }

  /// Asks before leaving the app for a member's LinkedIn page.
  Future<void> _confirmOpenLinkedIn(String? url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(tr('Buka LinkedIn member ini?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Buka')),
          ),
        ],
      ),
    );
    if (ok == true) await (widget.openLink ?? openHttpUrl)(url);
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    final query = _searchController.text.trim().toLowerCase();

    return all.where((p) {
      if (_major != kAllFilter && p['major'] != _major) return false;
      if (_year != kAllFilter && p['graduation_year']?.toString() != _year) {
        return false;
      }
      if (_industry != kAllFilter && p['industry'] != _industry) {
        return false;
      }
      if (_city != kAllFilter && (p['city'] as String?)?.trim() != _city) {
        return false;
      }
      if (query.isNotEmpty) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        final company = (p['company'] as String? ?? '').toLowerCase();
        if (!name.contains(query) && !company.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchController.text.isNotEmpty ||
      _major != kAllFilter ||
      _year != kAllFilter ||
      _industry != kAllFilter ||
      _city != kAllFilter;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _major = kAllFilter;
      _year = kAllFilter;
      _industry = kAllFilter;
      _city = kAllFilter;
      _industryController.text = kAllFilter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorView(
            message: friendlyLoadError('the members list', snapshot.error),
            screen: 'Members',
            error: snapshot.error,
            onRetry: () => setState(() {
              _future = _fetchAlumni();
            }),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = _applyFilters(all);
        final majors = distinctSortedValues(all, 'major');
        final years = [
          kAllFilter,
          ...all
              .map((p) => p['graduation_year']?.toString())
              .whereType<String>()
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a)),
        ];
        final industries = distinctSortedValues(all, 'industry');
        final cities = distinctSortedValues(
          all.map((p) => {'city': (p['city'] as String?)?.trim()}).toList(),
          'city',
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ClearableSearchField(
                controller: _searchController,
                hintText: tr('Cari nama atau perusahaan...'),
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
                    // A dropdown you can also type into to narrow the list.
                    child: SearchableChoice(
                      fieldKey: const Key('directory-industry'),
                      label: tr('Industry'),
                      controller: _industryController,
                      options: industries,
                      selected: _industry,
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _hasActiveFilters
                          ? '${filtered.length} dari ${all.length} alumni'
                          : '${all.length} alumni',
                      key: const Key('directory-count'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ClearFiltersButton(
                    active: _hasActiveFilters,
                    onPressed: _clearFilters,
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tr('Tidak ada alumni yang cocok.')),
                          if (_hasActiveFilters)
                            TextButton(
                              key: const Key('directory-empty-clear'),
                              onPressed: _clearFilters,
                              child: Text(tr('Hapus filter')),
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() => _future = _fetchAlumni());
                        try {
                          await _future;
                        } catch (_) {}
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = filtered[i];
                          return ListTile(
                            leading: Avatar(
                              url: p['avatar_url'] as String?,
                              name: p['name'] as String? ?? '',
                            ),
                            title: Text(p['name'] as String? ?? ''),
                            subtitle: Text(
                              [
                                if ((p['current_role'] as String?)
                                        ?.isNotEmpty ==
                                    true)
                                  '${p['current_role']}'
                                      '${_employerOf(p) != null ? ' @ ${_employerOf(p)}' : ''}',
                                '${p['major']} · Angkatan ${p['graduation_year']}',
                              ].join('\n'),
                            ),
                            isThreeLine: true,
                            trailing:
                                ((p['linkedin_url'] as String?)?.trim() ?? '')
                                    .isEmpty
                                ? null
                                : IconButton(
                                    key: Key('member-linkedin-${p['id']}'),
                                    tooltip: tr('Buka LinkedIn'),
                                    icon: const LinkedInLogo(),
                                    onPressed: () => _confirmOpenLinkedIn(
                                      p['linkedin_url'] as String?,
                                    ),
                                  ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileDetailScreen(
                                    profile: p,
                                    showEditButton: false,
                                    currentUser: widget.currentUser,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
