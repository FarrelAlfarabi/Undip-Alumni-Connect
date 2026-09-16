import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/filter_dropdown.dart';
import 'profile_detail_screen.dart';

/// Searchable alumni directory: filter by major, graduation year, and
/// industry, plus free-text search on name/company. Demo scope: fetches
/// all verified alumni_profiles rows once and filters client-side — fine
/// for ~24 seed rows, not meant to scale past the demo.
///
/// Faculty is not a filter here: this app is scoped to a single faculty
/// (Fakultas Ekonomika dan Bisnis / Ikafe), not campus-wide UNDIP, so
/// "faculty" carries no useful signal — major is the meaningful axis.
///
/// Always embedded as a tab inside AlumniScreen (no own AppBar/Scaffold) —
/// see alumni_screen.dart.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.currentUser});

  /// The verified alumnus browsing the directory, as a shared notifier —
  /// threaded through (same reference, not a copy) to ProfileDetailScreen
  /// so a subscribe action anywhere stays visible everywhere.
  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  final _searchController = TextEditingController();
  String _major = kAllFilter;
  String _year = kAllFilter;
  String _industry = kAllFilter;

  @override
  void initState() {
    super.initState();
    _future = _fetchAlumni();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchAlumni() async {
    final rows = await Supabase.instance.client
        .from('alumni_profiles')
        .select()
        .eq('verification_status', 'verified')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
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
      _industry != kAllFilter;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _major = kAllFilter;
      _year = kAllFilter;
      _industry = kAllFilter;
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load directory: ${snapshot.error}'),
            ),
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

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ClearableSearchField(
                controller: _searchController,
                hintText: 'Search by name or company...',
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilterDropdown(
                      label: 'Industry',
                      value: _industry,
                      options: industries,
                      onChanged: (v) => setState(() => _industry = v),
                    ),
                  ),
                ],
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
                  ? const Center(child: Text('No alumni match these filters.'))
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
                                    '${(p['current_employer'] as String?)?.isNotEmpty == true ? ' @ ${p['current_employer']}' : ''}',
                              '${p['major']} · Class of ${p['graduation_year']}',
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
