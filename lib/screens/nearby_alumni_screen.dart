import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/city_distances.dart';
import 'profile_detail_screen.dart';

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
class NearbyAlumniScreen extends StatefulWidget {
  const NearbyAlumniScreen({super.key, required this.currentUser});

  final ValueNotifier<Map<String, dynamic>> currentUser;

  @override
  State<NearbyAlumniScreen> createState() => _NearbyAlumniScreenState();
}

class _NearbyAlumniScreenState extends State<NearbyAlumniScreen> {
  late Future<List<Map<String, dynamic>>> _future;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myCity = widget.currentUser.value['city'] as String?;
    final myId = widget.currentUser.value['id'];

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Alumni')),
      body: Column(
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
      ),
    );
  }
}
