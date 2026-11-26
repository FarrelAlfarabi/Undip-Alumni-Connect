import 'dart:async';

import '../nav/back_guard.dart';

import 'package:flutter/material.dart';

import '../data/stale_cache.dart';

import '../widgets/responsive_list.dart';
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
/// bound as people join. Rows are ordered by name and read in pages (the
/// server returns at most 1000 rows a request), so the whole member list is
/// searchable, not only the first names of the alphabet.
const int kDirectoryMaxRows = 5000;

/// Reads rows page by page with [page] (inclusive `from` and `to` row
/// numbers) until a short page comes back or [maxRows] is reached.
Future<List<Map<String, dynamic>>> fetchAllPages(
  Future<List<Map<String, dynamic>>> Function(int from, int to) page, {
  int pageSize = 1000,
  int maxRows = kDirectoryMaxRows,
  int ahead = 1,
}) async {
  final all = <Map<String, dynamic>>[];
  var done = false;
  while (!done && all.length < maxRows) {
    final from = all.length;
    // [ahead] pages are asked at the same time, one round trip for all.
    final batch = await Future.wait([
      for (var i = 0; i < ahead; i++)
        page(from + i * pageSize, from + (i + 1) * pageSize - 1),
    ]);
    for (final rows in batch) {
      all.addAll(rows);
      if (rows.length < pageSize) {
        done = true;
        break;
      }
    }
  }
  return all.length > maxRows ? all.sublist(0, maxRows) : all;
}

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
  final _industryController = TextEditingController(text: tr(kAllFilter));
  String _major = kAllFilter;
  String _year = kAllFilter;
  String _industry = kAllFilter;
  String _city = kAllFilter;

  @override
  void initState() {
    super.initState();
    _future = _fetchAlumni();
    _searchController.addListener(_onSearchTyped);
  }

  /// What the list is filtered by. It follows the search box a moment after
  /// the last key, so fast typing is not held up by redrawing the list on
  /// every letter.
  final _query = ValueNotifier<String>('');
  Timer? _searchTimer;

  void _onSearchTyped() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _query.value) return;
    _searchTimer?.cancel();
    // Clearing the box shows everyone at once.
    if (next.isEmpty) {
      _query.value = next;
      return;
    }
    _searchTimer = Timer(kSearchDelay, () => _query.value = next);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _query.dispose();
    _searchController.removeListener(_onSearchTyped);
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

  String get _cacheKey => 'directory:${widget.currentUser.value['id']}';

  /// The last list this session, shown while the new one loads.
  List<Map<String, dynamic>>? get _stale =>
      StaleCache.peek<List<Map<String, dynamic>>>(_cacheKey);

  Future<List<Map<String, dynamic>>> _fetchAlumni() =>
      StaleCache.remember(_cacheKey, _loadAlumni());

  Future<List<Map<String, dynamic>>> _loadAlumni() async {
    if (widget.fetchAlumni != null) {
      return _withDefaultYear(
        await withoutBlockedProfiles(await widget.fetchAlumni!()),
      );
    }
    // The photo list does not depend on the member pages: ask both at once.
    final photos = AvatarRepository().urlsById()..ignore();
    final rows = await fetchAllPages(
      ahead: 2,
      (from, to) async => List<Map<String, dynamic>>.from(
        await Supabase.instance.client
                .from('alumni_profiles')
                .select(kProfileColumns)
                .eq('verification_status', 'verified')
                .order('name', ascending: true)
                .order('id', ascending: true)
                .range(from, to)
            as List,
      ),
    );
    return _withDefaultYear(
      await withoutBlockedProfiles(
        AvatarRepository.withAvatars(rows, await photos),
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
    final query = _query.value;

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
      _query.value.isNotEmpty ||
      _major != kAllFilter ||
      _year != kAllFilter ||
      _industry != kAllFilter ||
      _city != kAllFilter;

  void _clearFilters() {
    setState(() {
      _searchTimer?.cancel();
      _searchController.clear();
      _query.value = '';
      _major = kAllFilter;
      _year = kAllFilter;
      _industry = kAllFilter;
      _city = kAllFilter;
      _industryController.text = kAllFilter;
    });
  }

  // The filter lists (majors, years, industries, cities) only change when the
  // member list is fetched again, not on every keystroke. Computing them scans
  // and sorts all members, so they are kept until a new list arrives.
  List<Map<String, dynamic>>? _facetsSource;
  _Facets? _facetsCache;
  _Facets _facetsFor(List<Map<String, dynamic>> all) {
    if (!identical(_facetsSource, all) || _facetsCache == null) {
      _facetsSource = all;
      _facetsCache = _Facets.of(all);
    }
    return _facetsCache!;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      initialData: _stale,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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
        final facets = _facetsFor(all);
        final majors = facets.majors;
        final years = facets.years;
        final industries = facets.industries;
        final cities = facets.cities;

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
            // Only the count and the list follow the search box, so a key
            // press does not rebuild the search field and the four filters.
            Expanded(
              child: ListenableBuilder(
                listenable: _query,
                builder: (context, _) {
                  final filtered = _applyFilters(all);
                  return Column(
                    children: [
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
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
                                child: ResponsiveListView(
                                  minTileWidth: 300,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
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
                                          ((p['linkedin_url'] as String?)
                                                      ?.trim() ??
                                                  '')
                                              .isEmpty
                                          ? null
                                          : IconButton(
                                              key: Key(
                                                'member-linkedin-${p['id']}',
                                              ),
                                              tooltip: tr('Buka LinkedIn'),
                                              icon: const LinkedInLogo(),
                                              onPressed: () =>
                                                  _confirmOpenLinkedIn(
                                                    p['linkedin_url']
                                                        as String?,
                                                  ),
                                            ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          AppRoute(
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
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Options for the four filter dropdowns, worked out once per member list.
class _Facets {
  _Facets({
    required this.majors,
    required this.years,
    required this.industries,
    required this.cities,
  });

  factory _Facets.of(List<Map<String, dynamic>> all) => _Facets(
    majors: distinctSortedValues(all, 'major'),
    years: [
      kAllFilter,
      ...all
          .map((p) => p['graduation_year']?.toString())
          .whereType<String>()
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a)),
    ],
    industries: distinctSortedValues(all, 'industry'),
    cities: distinctSortedValues(
      all.map((p) => {'city': (p['city'] as String?)?.trim()}).toList(),
      'city',
    ),
  );

  final List<String> majors;
  final List<String> years;
  final List<String> industries;
  final List<String> cities;
}
