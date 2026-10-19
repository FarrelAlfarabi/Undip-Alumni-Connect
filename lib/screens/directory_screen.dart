import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/blocked_filter.dart';
import '../data/profile_columns.dart';
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
  });

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

  /// Opens on the user's own graduation year. Skipped when the profile has
  /// no year, or nobody in the list shares it (the dropdown would have no
  /// matching option). Only applied while the year filter is still "All".
  List<Map<String, dynamic>> _withDefaultYear(List<Map<String, dynamic>> rows) {
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
        List<Map<String, dynamic>>.from(rows as List),
      ),
    );
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
                hintText: 'Cari nama atau perusahaan...',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FilterDropdown(
                      label: 'Major',
                      value: _major,
                      options: majors,
                      onChanged: (v) => setState(() => _major = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilterDropdown(
                      label: 'Year',
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
                      label: 'Industry',
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
                      label: 'City',
                      value: _city,
                      options: cities,
                      onChanged: (v) => setState(() => _city = v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: ClearFiltersButton(
                active: _hasActiveFilters,
                onPressed: _clearFilters,
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Tidak ada alumni yang cocok.'),
                          if (_hasActiveFilters)
                            TextButton(
                              key: const Key('directory-empty-clear'),
                              onPressed: _clearFilters,
                              child: const Text('Hapus filter'),
                            ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            child: Text(
                              (p['name'] as String? ?? '?')
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .map((w) => w.isNotEmpty ? w[0] : '')
                                  .take(2)
                                  .join()
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(p['name'] as String? ?? ''),
                          subtitle: Text(
                            [
                              if ((p['current_role'] as String?)?.isNotEmpty ==
                                  true)
                                '${p['current_role']}'
                                    '${_employerOf(p) != null ? ' @ ${_employerOf(p)}' : ''}',
                              '${p['major']} · Angkatan ${p['graduation_year']}',
                            ].join('\n'),
                          ),
                          isThreeLine: true,
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
          ],
        );
      },
    );
  }
}
