# Nearby Alumni: real map, placed by profile city

Status: first version built behind a flag (`REAL_MAP`), off in production.
Vercel preview builds turn it on so it can be tried on the preview link.

## The rule
Pins come from the city in each profile. The app never asks for device
location. A pin is the CENTRE of the city, so alumni of one city share one pin
with a count. Showing them at different spots inside a city would pretend to
know more than we do.

## What was there
`lib/widgets/nearby_map_view.dart`: a hand-painted picture, not a map. Cities
are spread in a circle by distance rank, so it never matched geography. It
worked for 8 cities; with 100 cities it would mislead.

## What was built
| Piece | File |
|---|---|
| Map screen widget | `lib/widgets/real_nearby_map.dart` (flutter_map, no API key) |
| City centres, 100 cities | `lib/data/indonesian_cities.dart` |
| Distances | `lib/data/city_distances.dart` (hand entered for the 8 seeded cities, straight-line for the rest) |
| Flag, tile URL, credit | `lib/config/map_config.dart` |
| Nearby screen | picks the real map when `REAL_MAP` is on; city sheet and chips unchanged |
| Vercel | preview builds set `REAL_MAP=true`; `REAL_MAP=true` env var forces it elsewhere |

Buttons (top right): center on my city, show all, point north, zoom in, zoom out. Rotation is locked, north is always up.

Behaviour: map opens fitted to the viewer's city plus every city with alumni.
One pin per city with a count. One alumnus: tap opens the profile. Several:
tap opens the existing city sheet (chat, WhatsApp invite). "You" sits under
your own city's pin. Alumni whose city has no known centre are left off the map
but stay in the list.

## Options for the map picture (tiles)
| Option | Cost | Verdict |
|---|---|---|
| OpenStreetMap public tiles (current default) | free | OK for a small beta only. Its rules forbid heavy or commercial use and it can block an app. Credit is shown. |
| MapTiler / Stadia / Thunderforest | free tier, then paid, needs a key | Recommended for release. Same code: set `MAP_TILE_URL` and `MAP_ATTRIBUTION`, add the host to `connect-src` in `vercel.json`. |
| Google Maps | needs billing account and key, web setup is heavier | Not worth it for pins on a city map. |
| Self hosted tiles | server and storage work | Overkill. |

A key placed in a web build is visible to anyone. Use a provider that lets you
restrict the key to your domain.

## Accuracy
City centres are rounded to 2 decimals (about 1 km) and typed from knowledge,
not looked up. Tests check each is inside Indonesia, none repeat, and six well
known cities are within 0.3 degrees. That catches typos, not small errors. To be
sure, run a one time lookup of the 100 names against a geocoder (Nominatim or
the provider's geocoder) and compare. I could not do it from here: the sandbox
blocks those hosts. A few names (Solo, Tidore) are the common name, not the
official one.

Distances: the 8 seeded cities keep their old hand entered road-ish numbers;
other pairs are straight-line, rounded to 10 km. They are estimates ("about N
km"), not driving distance.

## Not verified
- Tiles were never loaded: the sandbox cannot reach any tile server. Tests turn
  the picture layer off. The web build compiles. Open the preview link and
  check the map actually draws.
- Not tried on a phone (pinch, drag, tap targets).
- Dark mode: tiles are light only. The old map followed system dark mode.

## Decisions for you
1. Tile provider for release (recommend MapTiler or Stadia free tier).
2. Keep the old painted map as a fallback, or delete it once the real one is
   confirmed (it is about 500 lines and has its own test).
3. Show the real map to everyone from the next release, or keep the flag until
   you have checked the preview.

## Free tier now, swap later (decision 14 Oct 2026)
- Start on a free tier. MapTiler is the pick: set at build time (no code change)
  `MAP_TILE_URL=https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=YOUR_KEY`
  and `MAP_ATTRIBUTION=© MapTiler © OpenStreetMap contributors`. The free
  allowance and its terms (free plans are usually for non commercial use) must
  be checked on maptiler.com at sign up, I could not verify them from here.
- Swapping provider later is the same two build settings, nothing else.
- If tiles start failing (quota used up, bad key), the map shows
  "Map background unavailable. Pins still work." instead of a silent grey map.
- Watching usage: the provider's dashboard shows requests against the quota.
  Check it weekly during the beta and turn on any usage email alert it offers.
  The app does not count tile requests itself (a per phone count would be wrong).
