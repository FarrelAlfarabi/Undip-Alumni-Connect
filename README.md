# Lingkaran — MVP demo

(Formerly "UNDIP Alumni Connect"; the repo, Dart package and Vercel project keep the old name.)

Flutter + Supabase demo of a verified alumni directory with a job referral
board, subscription-gated messaging, and an Ikafe announcements feed.
**Dummy data only.** No real alumni, no real payment, no real NIM
verification — see `PROJECT_NOTES.md` for the running log of what exists
and why, and `DEMO_SCRIPT.md` for the walkthrough used on demo day.

## Running it

Requirements: Flutter SDK (stable) and a `.env` file with the Supabase
project's URL and publishable (anon) key.

```bash
cp .env.example .env    # then fill in SUPABASE_URL and SUPABASE_ANON_KEY
flutter pub get
flutter run -d chrome   # or: flutter run -d web-server --web-port 8000
```

`.env` is gitignored and is bundled into the build as an asset — a missing
`.env` fails the build with an asset error, which is the intended signal.

If `flutter run` is slow to start (first run in a fresh environment), the
release build serves faster:

```bash
flutter build web --release
cd build/web && python3 -m http.server 8000
```

## Test accounts

Verification is an exact-match on `alumni_profiles.email`. Use
`ahmad.ramadhan@example.com` (seeded `free`, so the paywall shows). The
full list is at the top of `supabase/seed.sql`.

## Database

Schema lives in `supabase/migrations/`, seed data in `supabase/seed*.sql`.
Apply in order against a fresh project: migrations, then `seed.sql`, then
`seed_job_posts.sql` and `seed_announcements.sql` (those two are not
idempotent — run them once).

Row Level Security is on, but only as vandalism guardrails (no delete
anywhere, no fake profiles, profile edits locked to the columns the app
actually writes) — see `supabase/migrations/20260915120000_add_basic_rls.sql`.
There is no real login in this app (verification is a plain email match,
not a Supabase Auth session), so RLS cannot hide alumni data from anyone
holding the anon key; the whole directory and all messages are still
world-readable. Do not reuse this project or key for anything beyond the
demo.

## Marketplace (demo)

An alumni-to-alumni marketplace, opened from the **Marketplace** tile on Home. **Demo only: dummy
data, no real payments, no checkout, nothing is charged.** Every marketplace screen
shows a "Demo only, no real payments" notice.

- Anyone can browse approved listings. Only **subscribers** can post.
- A new or edited listing is `pending` until an **admin** approves it (or
  rejects it with a reason the seller can see). Sellers can mark an approved
  listing sold (hidden from browse) or delete their own listings.
- Buyers use the seller's shop link and/or contact info. There is no in-app
  checkout or messaging link.
- Anyone can report an approved listing (spam, prohibited item, misleading,
  other). Admins see report counts per listing. There is no block feature.

**Files:** migrations `supabase/migrations/20260930*_marketplace_*.sql`,
seed `supabase/seed_marketplace.sql`, SQL checks in `supabase/tests/`,
Dart in `lib/{models,data,screens}/marketplace_*`, tests in `test/`.

**Run the demo database.** Do NOT apply these migrations to the shared live
project the `main`/`demo` branches use. Use a separate project or a
Supabase branch database, then apply the four `marketplace_*` migrations in
order, `seed.sql`, then `seed_marketplace.sql`. The seed is idempotent
(fixed ids, safe to run twice) and makes the profile
`farrel.abi.saleh@gmail.com` the demo admin. To add another admin, insert
its profile id into `marketplace_admins` from the dashboard.

**Admin passphrase (after the security migrations).** The admin's profile id is
public, so every admin action also needs a passphrase, checked in the
database against a bcrypt hash. Nobody is admin until you set one from the SQL
editor: `select marketplace_set_admin_key('<admin profile uuid>', '<16+
character passphrase>');`. The Marketplace admin screen asks for it each time
and keeps it only in memory. See `SECURITY_AUDIT.md` (SA-04). Never re-run only
the original `20260930090*` marketplace migrations on a database that has the
security migrations: they recreate the old id-only admin functions. Apply all
`2026093*` migrations in order.

**SQL/RLS checks (no Supabase needed).** `supabase/tests/run_local.sh`
starts a throwaway local Postgres (needs the Postgres server binaries and
`psql`), applies every migration and seed, runs the marketplace migrations
and seed a second time to prove they are idempotent, then runs the
assertions. It uses stand-in roles and schemas, so it is an approximation of
Supabase, not the real thing.

**Dart checks:** `flutter analyze`, `flutter test`, `flutter build web`.

### Known gaps (what this demo cannot enforce)

The app has no real login (verification is an email match), so every
request reaches Postgres as `anon` and RLS cannot know who is calling.

- The database blocks all direct writes to listings and only shows
  `approved` rows to direct reads. Everything else goes through
  `SECURITY DEFINER` functions that take the profile id **sent by the app**.
  That id is not authenticated: anyone who knows or guesses another
  profile's id can post, edit, delete, read the pending/rejected listings
  of, or report as that person. Admin actions have the same weakness, and
  `marketplace_is_admin(id)` lets anyone test whether an id is an admin.
- "Subscribers only" (job posting, marketplace posting) checks
  `subscription_status`. A plain UPDATE of that column is now blocked, but
  while `billing_settings.demo_subscriptions` is true any client can call
  `demo_subscribe(<profile id>)` for any profile, so it is still a speed bump.
  Before real payments run `update billing_settings set demo_subscriptions =
  false;` and let only a payment webhook (service_role) set the status.
  Apply `20261001090000_job_posting_requires_subscriber.sql` and ship the app
  build that calls `demo_subscribe` together: either one alone breaks the
  Subscribe button. Checks: `supabase/tests/run_job_gate_local.sh`.
- Contact info on approved listings is readable by anyone holding the anon
  key, not only signed-in members.
- The `marketplace` image bucket allows uploads (images only, 2 MB) from
  anyone holding the anon key.
- Real enforcement needs real Supabase Auth (`auth.uid()`), which is a
  separate piece of work.

## Home hub, Preview tiles and the lock screen

**Home hub.** After verification the app lands on a Home tab: a greeting, a
banner carousel of the latest Ikafe announcements (text cards, auto-advance,
swipe, tap for the full text), quick tiles (Jobs, Marketplace, Directory,
Nearby Alumni), a "Latest" strip (3 newest jobs, 3 newest approved
marketplace listings) and an Upcoming section. The bottom navigation is
Home, Directory, Chat, Profile. Jobs, News ("See all announcements"),
Marketplace and Nearby open from Home with a back arrow. The Marketplace
"Demo only, no real payments" notice still shows on every marketplace screen.

**Upcoming Preview tiles.** Events, Mentoring and Business directory are
non-functional tiles marked "Preview". Tapping one only opens an info sheet.
No data, no dates, no tracking, no money features.

**Lock screen (Android and iOS only).** After the first successful
verification the app remembers, on that device only, the profile id, a
display name and a masked email hint (`f***@gmail.com`), all in the
platform secure storage (Keychain / Keystore). It then offers a 6-digit PIN
(and fingerprint, if the device has it). On the next launch a
remembered person sees a lock screen instead of the Welcome screen; new users
see Welcome and Verification as before.

- The PIN is stored only as a salted PBKDF2-HMAC-SHA256 hash, never as text
  and never in logs.
- 5 wrong PINs wipe the local unlock data and require full verification; a
  cool-down starts after the 3rd wrong try; remaining attempts are shown.
- Biometrics are optional and never the only way in; if the prompt fails
  or is cancelled, the PIN pad is the fallback.
- The lock screen shows again after the app has been in the background for
  more than 5 minutes (`kLockAfterBackground` in `lib/lock/lock_config.dart`).
- "Forgot PIN? Verify again" and "Not you? Switch account" clear all the local
  data. Profile > Sign out forgets who is signed in but keeps the PIN: verifying
  again as the same person asks for the PIN they already made instead of
  creating a new one. A different person verifying on the phone drops it.
  Nothing is deleted on the server.
- If the PIN step is skipped, the next launch shows a "Continue" button that
  runs verification again.
- **Web has no lock screen in production** (Vercel *preview* builds turn it on for testing only, via `--dart-define=WEB_LOCK_TEST=true` in `scripts/vercel-build.sh`; that is not real protection). Browsers have no real secure storage and no
  biometrics API here, so a remembered id and PIN hash would sit in
  localStorage where a PIN of 1,000,000 possibilities can be guessed offline
  in moments. A lock that looks safe but is not is worse than none, so on web
  every visit starts at Welcome, as before.

**Honesty rule: this is a device convenience lock, not real security.**
Verification is still an email match with no real login (no OTP, no Supabase
Auth session). Anyone who knows a valid alumni email can still verify as that
person, on any device, and the PIN does not stop that. The lock only saves the
owner from re-verifying on every launch and keeps a casual bystander out of an
unlocked phone. It does not protect the data in the database.

**Manual click-test:** `docs/hub/CLICK_TEST_CHECKLIST.md`.

**Known gaps.** Not tested on a real Android or iOS device (only in
widget tests with fakes and on the web build). Android needs
`FlutterFragmentActivity`, the `USE_BIOMETRIC` permission and an AppCompat
launch theme; these are set but have not been built for either platform here. A PIN of 6 digits can be
guessed offline by someone who can read the secure storage of a rooted
device; the 5-attempt wipe only limits guessing through the app. The app
switcher may show a screenshot of the last screen (there is no privacy
screen).

## Deploying to Vercel

The Vercel project is connected to this repo's `claude/eloquent-maxwell-pzaky1`
branch and auto-deploys on push (check Vercel project Settings → Git if
this changes). Vercel has no Flutter SDK by default, so
`vercel.json` points it at `scripts/vercel-build.sh`, which fetches
Flutter fresh on each build and runs the normal release build.

One manual step: `SUPABASE_URL` and `SUPABASE_ANON_KEY` are gitignored
(same as local dev) and must be set once as **Vercel project Environment
Variables** (Settings → Environment Variables, both Production and
Preview) — use the same values as your local `.env`. The build fails
loudly with a clear error if these aren't set.
