import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/city_distances.dart';
import '../widgets/nearby_map_view.dart';
import 'city_group_chat_screen.dart';
import 'profile_detail_screen.dart';

/// One city's worth of nearby alumni, grouped for the map's networking
/// chips and the sheet they open (_CityClusterSheet).
class _CityCluster {
  const _CityCluster({
    required this.city,
    required this.km,
    required this.alumni,
  });

  final String city;
  final int km;
  final List<Map<String, dynamic>> alumni;
}

/// "Nearby Alumni" — demo-only proximity feature.
///
/// DEMO SCOPE: distances are simulated from each alumnus's seeded `city`
/// field against a static lookup table (see lib/data/city_distances.dart),
/// not real device GPS. No location permission is ever requested and no
/// one's actual location is read or stored — this was a deliberate choice.
/// Real, live location-sharing between alumni who may not otherwise know
/// each other has genuine safety implications (stalking risk chief among
/// them) that weren't designed for and are explicitly out of scope for
/// this demo. This screen exists to show the concept, not to ship it.
///
/// The Map tab (added 17 Sep 2026, Master Plan §3.4 item 6; restyled to
/// look like Google Maps with a per-person marker shortly after) plots
/// each alumnus individually at their city's real-world coordinates —
/// see nearby_map_view.dart's doc comment for why this still isn't a
/// real map integration (no SDK, no API key, no tiles) and still never
/// touches real GPS. Below the map, a row of per-city chips opens
/// networking actions (city group chat, WhatsApp invite) for that whole
/// city's alumni at once instead of requiring one-by-one messaging — see
/// _CityClusterSheet below.
///
/// Always embedded as a tab inside AlumniScreen (no own AppBar/Scaffold) —
/// see alumni_screen.dart.
class NearbyAlumniScreen extends StatefulWidget {
  const NearbyAlumniScreen({super.key, required this.currentUser});

  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<NearbyAlumniScreen> createState() => _NearbyAlumniScreenState();
}

class _NearbyAlumniScreenState extends State<NearbyAlumniScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _future = _fetchAlumni();
  }

  Future<List<Map<String, dynamic>>> _fetchAlumni() async {
    final rows = await Supabase.instance.client
        .from('alumni_profiles')
        .select()
        .eq('verification_status', 'verified')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  void _openClusterSheet(_CityCluster cluster) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _CityClusterSheet(cluster: cluster, currentUser: widget.currentUser),
    );
  }

  void _openProfile(Map<String, dynamic> profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(
          profile: profile,
          currentUser: widget.currentUser,
          showEditButton: false,
        ),
      ),
    );
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('List'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Map'),
                  icon: Icon(Icons.map_outlined),
                ),
              ],
              selected: {_showMap},
              onSelectionChanged: (s) => setState(() => _showMap = s.first),
            ),
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load nearby alumni: ${snapshot.error}',
                    ),
                  ),
                );
              }

              if (myCity == null || myCity.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Your profile has no city on file, so nearby '
                      'distances can\'t be simulated for you.',
                      textAlign: TextAlign.center,
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

              if (_showMap) {
                final byCity = <String, List<Map<String, dynamic>>>{};
                final kmByCity = <String, int>{};
                for (final e in withDistance) {
                  final city = e.profile['city'] as String? ?? 'Unknown';
                  byCity.putIfAbsent(city, () => []).add(e.profile);
                  kmByCity[city] = e.km!;
                }
                final clusters = byCity.entries
                    .map(
                      (e) => _CityCluster(
                        city: e.key,
                        km: kmByCity[e.key]!,
                        alumni: e.value,
                      ),
                    )
                    .toList();
                final pins = withDistance
                    .map((e) => AlumniPin(profile: e.profile, km: e.km!))
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NearbyMapView(
                        myCity: myCity,
                        pins: pins,
                        onPinTap: (pin) => _openProfile(pin.profile),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pinch or drag to explore. Tap a marker to view '
                        'that alumnus, or hover for a quick preview.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Network with a whole city at once',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cluster in clusters)
                            ActionChip(
                              avatar: const Icon(
                                Icons.groups_outlined,
                                size: 18,
                              ),
                              label: Text(
                                '${cluster.city} (${cluster.alumni.length})',
                              ),
                              onPressed: () => _openClusterSheet(cluster),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: withDistance.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final entry = withDistance[i];
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
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for a tapped city chip below the map: who's there, plus
/// two networking actions in place of messaging each person one by
/// one — an in-app group chat (real, functional) and a WhatsApp invite
/// share (opens WhatsApp with a prefilled message the user sends
/// manually; WhatsApp has no API to auto-create a group, so this is
/// honestly an invite/share action, not automated group creation).
class _CityClusterSheet extends StatelessWidget {
  const _CityClusterSheet({required this.cluster, required this.currentUser});

  final _CityCluster cluster;
  final ValueNotifier<Map<String, dynamic>> currentUser;

  Future<void> _inviteViaWhatsApp(BuildContext context) async {
    final text =
        'Hi! Fellow Ikafe alumni in ${cluster.city} — let\'s connect. '
        'I\'m starting a WhatsApp group for us, join in!';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              cluster.city,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              cluster.km == 0
                  ? 'Same city as you · ${cluster.alumni.length} alumni'
                  : '~${cluster.km} km away · ${cluster.alumni.length} alumni',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('Network with the group', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CityGroupChatScreen(
                      city: cluster.city,
                      currentUser: currentUser,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.forum_outlined),
              label: Text('Open ${cluster.city} Group Chat'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _inviteViaWhatsApp(context),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Invite via WhatsApp'),
            ),
            const SizedBox(height: 20),
            Text('Alumni here', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cluster.alumni.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = cluster.alumni[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(p['name'] as String? ?? ''),
                    subtitle: Text(p['current_role'] as String? ?? ''),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileDetailScreen(
                            profile: p,
                            currentUser: currentUser,
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
        ),
      ),
    );
  }
}
