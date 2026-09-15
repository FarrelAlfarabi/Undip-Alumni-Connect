import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_detail_screen.dart';

const _kAllFilter = 'All';

/// Searchable alumni directory: filter by faculty, graduation year, and
/// industry, plus free-text search on name/company. Demo scope: fetches
/// all verified alumni_profiles rows once and filters client-side — fine
/// for ~24 seed rows, not meant to scale past the demo.
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
  String _faculty = _kAllFilter;
  String _year = _kAllFilter;
  String _industry = _kAllFilter;

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
      if (_faculty != _kAllFilter && p['faculty'] != _faculty) return false;
      if (_year != _kAllFilter && p['graduation_year']?.toString() != _year) {
        return false;
      }
      if (_industry != _kAllFilter && p['industry'] != _industry) {
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

  List<String> _distinctSorted(List<Map<String, dynamic>> all, String field) {
    final values =
        all
            .map((p) => p[field]?.toString())
            .whereType<String>()
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [_kAllFilter, ...values];
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
        final faculties = _distinctSorted(all, 'faculty');
        final years = [
          _kAllFilter,
          ...all
              .map((p) => p['graduation_year']?.toString())
              .whereType<String>()
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a)),
        ];
        final industries = _distinctSorted(all, 'industry');

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by name or company...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterDropdown(
                      label: 'Faculty',
                      value: _faculty,
                      options: faculties,
                      onChanged: (v) => setState(() => _faculty = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterDropdown(
                      label: 'Year',
                      value: _year,
                      options: years,
                      onChanged: (v) => setState(() => _year = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterDropdown(
                      label: 'Industry',
                      value: _industry,
                      options: industries,
                      onChanged: (v) => setState(() => _industry = v),
                    ),
                  ),
                ],
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
                              '${p['faculty']} · Class of ${p['graduation_year']}',
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

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
