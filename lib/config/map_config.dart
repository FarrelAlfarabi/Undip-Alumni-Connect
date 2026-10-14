/// Real map for Nearby Alumni. Off by default: the hand-drawn map stays.
/// Turn on with `--dart-define=REAL_MAP=true` (Vercel PREVIEW builds do it
/// automatically, see scripts/vercel-build.sh).
const bool kRealMap = bool.fromEnvironment('REAL_MAP');

/// Where map pictures (tiles) come from. The default is the free OpenStreetMap
/// server, which is fine for a small beta but NOT for a public release: its
/// rules forbid heavy use. Before release, pick a provider with a key (for
/// example MapTiler, Stadia or Thunderforest), build with
/// `--dart-define=MAP_TILE_URL=...` and add its host to `connect-src` in
/// vercel.json. See docs/NEARBY_MAP_PLAN.md.
const String kMapTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

/// Credit shown in the corner of the map. Providers require it.
const String kMapAttribution = String.fromEnvironment(
  'MAP_ATTRIBUTION',
  defaultValue: '© OpenStreetMap contributors',
);
