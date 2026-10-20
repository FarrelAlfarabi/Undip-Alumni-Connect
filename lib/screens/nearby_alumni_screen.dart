import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/feature_flags.dart';
import '../data/blocked_filter.dart';
import '../data/city_distances.dart';
import '../data/city_group_repository.dart';
import '../data/profile_columns.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import 'city_group_chat_screen.dart';
import 'profile_detail_screen.dart';
import 'profile_setup_screen.dart';

/// "Nearby Alumni": a list of verified alumni, nearest city first, with a
/// city filter. Picking a city shows that city's WhatsApp group: members open
/// it with one tap, and any member can add or change the invite link (the app
/// cannot create a WhatsApp group by itself, see 20261019110000_city_whatsapp_groups).
///
/// DEMO SCOPE: distances are simulated from each alumnus's profile `city`
/// against a static lookup table (see lib/data/city_distances.dart), not real
/// device GPS. No location permission is ever requested and no one's actual
/// location is read or stored: real location-sharing between alumni who may
/// not know each other has safety risks (stalking chief among them) that were
/// deliberately left out. The map that used to sit beside this list was
/// removed on 19 Oct 2026; the list and the city filter replace it.
///
/// Always embedded as a tab inside AlumniScreen (no own AppBar/Scaffold) -
/// see alumni_screen.dart.
class NearbyAlumniScreen extends StatefulWidget {
  const NearbyAlumniScreen({
    super.key,
    required this.currentUser,
    this.fetchAlumni,
    this.chat = chatEnabled,
    this.groups,
    this.openUrl,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// Injectable for tests; defaults to the Supabase query.
  final Future<List<Map<String, dynamic>>> Function()? fetchAlumni;

  /// Whether city group chat is offered (the app-wide switch).
  final bool chat;

  /// City WhatsApp links. Injectable for tests.
  final CityGroupRepository? groups;

  /// Opens a link outside the app. Injectable for tests.
  final Future<bool> Function(Uri uri)? openUrl;

  @override
  State<NearbyAlumniScreen> createState() => _NearbyAlumniScreenState();
}

class _NearbyAlumniScreenState extends State<NearbyAlumniScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  late final CityGroupRepository _groups =
      widget.groups ?? CityGroupRepository();
  Map<String, String> _links = {};
  String? _city;

  @override
  void initState() {
    super.initState();
    _future = _fetchAlumni();
    _loadLinks();
  }

  Future<List<Map<String, dynamic>>> _fetchAlumni() async {
    if (widget.fetchAlumni != null) {
      return withoutBlockedProfiles(await widget.fetchAlumni!());
    }
    final rows = await Supabase.instance.client
        .from('alumni_profiles')
        .select(kProfileColumns)
        .eq('verification_status', 'verified')
        .order('name', ascending: true);
    return withoutBlockedProfiles(
      List<Map<String, dynamic>>.from(rows as List),
    );
  }

  /// A failed links load only hides the WhatsApp buttons' current state; the
  /// list itself still works.
  Future<void> _loadLinks() async {
    final id = widget.currentUser.value['id'];
    if (id == null) return;
    try {
      final links = await _groups.list('$id');
      if (mounted) setState(() => _links = links);
    } catch (_) {}
  }

  Future<void> _join(String url) async {
    final uri = Uri.parse(url);
    final ok = widget.openUrl != null
        ? await widget.openUrl!(uri)
        : await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp tidak bisa dibuka.')),
      );
    }
  }

  Future<void> _editLink(String city) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _GroupLinkDialog(
        city: city,
        initial: _links[city],
        save: (url) =>
            _groups.save('${widget.currentUser.value['id']}', city, url),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _links = {..._links, city: saved});
  }

  /// Opens the profile editor, where the city is chosen, and refreshes
  /// Nearby with the saved profile.
  Future<void> _setCity() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(profile: widget.currentUser.value),
      ),
    );
    if (updated == null || !mounted) return;
    widget.currentUser.value = updated;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myCity = widget.currentUser.value['city'] as String?;
    final myId = widget.currentUser.value['id'];

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.secondaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demo: simulated from each profile\'s city, not real '
                  'GPS. No location is requested or tracked.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorView(
                  message: friendlyLoadError('nearby alumni', snapshot.error),
                  screen: 'Nearby alumni',
                  error: snapshot.error,
                  onRetry: () => setState(() {
                    _future = _fetchAlumni();
                    _loadLinks();
                  }),
                );
              }
              if (myCity == null || myCity.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Your profile has no city on file, so nearby '
                          'distances can\'t be simulated for you.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const Key('nearby-set-city'),
                          onPressed: _setCity,
                          icon: const Icon(Icons.location_city_outlined),
                          label: const Text('Set your city'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final others = (snapshot.data ?? [])
                  .where((p) => p['id'] != myId)
                  .toList();

              final withDistance =
                  others
                      .map((p) {
                        final city = p['city'] as String?;
                        final km = approxDistanceKm(myCity, city);
                        return (profile: p, km: km);
                      })
                      .where((e) => e.km != null)
                      .toList()
                    ..sort((a, b) => a.km!.compareTo(b.km!));

              if (withDistance.isEmpty) {
                return const Center(
                  child: Text('No other alumni with a known city yet.'),
                );
              }

              final cities = <String, int>{};
              for (final e in withDistance) {
                final c = e.profile['city'] as String? ?? '';
                cities[c] = (cities[c] ?? 0) + 1;
              }
              final selected = cities.containsKey(_city) ? _city : null;
              final shown = selected == null
                  ? withDistance
                  : withDistance
                        .where((e) => e.profile['city'] == selected)
                        .toList();

              return Column(
                children: [
                  _CityFilter(
                    cities: cities,
                    total: withDistance.length,
                    selected: selected,
                    onSelected: (c) => setState(() => _city = c),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: shown.length + (selected == null ? 0 : 1),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (selected != null && i == 0) {
                          return _CityGroupCard(
                            city: selected,
                            count: cities[selected]!,
                            link: _links[selected],
                            chat: widget.chat,
                            currentUser: widget.currentUser,
                            onJoin: _join,
                            onEdit: () => _editLink(selected),
                          );
                        }
                        final entry = shown[selected == null ? i : i - 1];
                        final p = entry.profile;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              (p['name'] as String? ?? '?')
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .map((w) => w.isNotEmpty ? w[0] : '')
                                  .take(2)
                                  .join()
                                  .toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(p['name'] as String? ?? ''),
                          subtitle: Text(
                            '${p['current_role'] ?? ''} · ${p['city'] ?? ''}',
                          ),
                          trailing: Text(
                            entry.km == 0 ? 'Same city' : '~${entry.km} km',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileDetailScreen(
                                  profile: p,
                                  currentUser: widget.currentUser,
                                  showEditButton: false,
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
          ),
        ),
      ],
    );
  }
}

/// Searchable city dropdown: "Semua" plus every city that has alumni, nearest
/// first, each with its alumni count. Typing narrows the choices.
class _CityFilter extends StatelessWidget {
  const _CityFilter({
    required this.cities,
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  final Map<String, int> cities;
  final int total;
  final String? selected;
  final ValueChanged<String?> onSelected;

  // Value of the "Semua" entry; a real city is never empty.
  static const _all = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: LayoutBuilder(
        builder: (context, box) => DropdownMenu<String>(
          key: const Key('nearby-city-field'),
          width: box.maxWidth,
          label: const Text('Kota'),
          leadingIcon: const Icon(Icons.location_city_outlined),
          trailingIcon: const Icon(
            Icons.arrow_drop_down,
            semanticLabel: 'Show Kota options',
          ),
          selectedTrailingIcon: const Icon(
            Icons.arrow_drop_up,
            semanticLabel: 'Hide Kota options',
          ),
          initialSelection: selected ?? _all,
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: 280,
          dropdownMenuEntries: [
            DropdownMenuEntry<String>(value: _all, label: 'Semua ($total)'),
            for (final e in cities.entries)
              DropdownMenuEntry<String>(
                value: e.key,
                label: '${e.key} (${e.value})',
              ),
          ],
          onSelected: (v) => onSelected(v == null || v == _all ? null : v),
        ),
      ),
    );
  }
}

/// Top of the list once a city is picked: its WhatsApp group (join, or add the
/// link when nobody has yet) and, when chat is on, the city group chat.
class _CityGroupCard extends StatelessWidget {
  const _CityGroupCard({
    required this.city,
    required this.count,
    required this.link,
    required this.chat,
    required this.currentUser,
    required this.onJoin,
    required this.onEdit,
  });

  final String city;
  final int count;
  final String? link;
  final bool chat;
  final ValueNotifier<Map<String, dynamic>> currentUser;
  final ValueChanged<String> onJoin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$city · $count alumni',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (link != null) ...[
                FilledButton.icon(
                  key: const Key('nearby-wa-join'),
                  onPressed: () => onJoin(link!),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Gabung grup WhatsApp'),
                ),
                TextButton(
                  key: const Key('nearby-wa-edit'),
                  onPressed: onEdit,
                  child: const Text('Ubah link'),
                ),
              ] else
                OutlinedButton.icon(
                  key: const Key('nearby-wa-add'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Tambah link grup WhatsApp'),
                ),
              if (chat)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CityGroupChatScreen(
                        city: city,
                        currentUser: currentUser,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.forum_outlined),
                  label: Text('Open $city Group Chat'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks for a city's WhatsApp invite link. Pops with the saved link, or null.
/// Checks the link shape here first; the database checks it again.
class _GroupLinkDialog extends StatefulWidget {
  const _GroupLinkDialog({
    required this.city,
    required this.initial,
    required this.save,
  });

  final String city;
  final String? initial;
  final Future<void> Function(String url) save;

  @override
  State<_GroupLinkDialog> createState() => _GroupLinkDialogState();
}

class _GroupLinkDialogState extends State<_GroupLinkDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _controller.text.trim();
    if (!isWhatsAppInviteUrl(url)) {
      setState(
        () => _error = cityGroupErrorMessage(
          const CityGroupException(CityGroupErrorCode.invalidInput),
        ),
      );
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.save(url);
      if (mounted) Navigator.of(context).pop(url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = cityGroupErrorMessage(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Grup WhatsApp ${widget.city}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buat grup di WhatsApp, lalu tempel link undangannya di sini. '
              'Semua alumni di kota ini bisa melihatnya.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('nearby-wa-field'),
              controller: _controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link undangan',
                hintText: 'https://chat.whatsapp.com/...',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('nearby-wa-save'),
          onPressed: _saving ? null : _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
