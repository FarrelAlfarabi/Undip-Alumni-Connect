# Lingkaran — MVP demo

(Formerly "UNDIP Alumni Connect"; the repo, Dart package and Vercel project keep the old name.)

Flutter + Supabase app for FEB UNDIP alumni (via Ikafe): a verified alumni
directory, a job board, a business directory with UMKM bands, a marketplace
for products from approved businesses, requests to contact, and an Ikafe
announcements feed. **Closed beta (about 15 testers).** It is free: there is
no subscription and no payment in the app. Chat is hidden and replaced by
"request to contact". There is no real login yet, so read "Closed beta
warning" below before inviting anyone. `PROJECT_NOTES.md` is the running log,
`docs/STAGE_LOG.md` and `docs/DECISIONS.md` cover the free-launch work, and
`DEMO_SCRIPT.md` is the walkthrough.

## Closed beta warning

Read `docs/BETA_RULES.md` before inviting anyone (operator checklist and what
testers are told). The plan for real login is `docs/AUTH_MIGRATION_PLAN.md`.
After the beta hardening migrations (`20261005*`), `verification_status` can no
longer be set by the app, and `email_log`, the chat tables and the notifications
table are closed to the public key. Everything below that is still true stays
true until login ships.

- Closed beta only. There is no real login (Supabase Auth). Anyone who knows
  an email or a profile id can act as that person, including admins and
  account deletion.
- The directory still sends every person's email and NIM to every client.
- The public web version uses the same database.
- Push notifications, release signing, store accounts and backups are missing.
- The privacy policy is self-written and needs review before a public launch.
- Testers get the debug APK from the GitHub Actions run (artifact
  `lingkaran-<version>+<run number>-debug`, kept 7 days). Secrets: `SUPABASE_URL`,
  `SUPABASE_ANON_KEY`, optional `ANDROID_DEBUG_KEYSTORE_BASE64`.

## Free launch features (Stages 1 to 8)

- Four tabs: Home, Directory, Market (Products and Businesses), Profile.
- Business directory: any alumnus can register a business (several allowed).
  An admin approves, rejects or suspends it. Yearly sales pick a UMKM band
  (PP 7/2021 Art. 35).
- Marketplace: products only from approved businesses. Free limit by band;
  `unlimited_until` is set in the dashboard only. Sold items do not count.
- Request to contact (replaces chat), notifications inside the app only,
  report and block, "Send feedback" on errors.
- Admins come from the `app_admins` table (no passphrase). Add them in the
  SQL editor, see the header of
  `supabase/migrations/20261003130000_app_admins.sql`.
- Account deletion, privacy policy and consent screen, BETA label and the
  version in Profile > About and on the Welcome screen.
- The Nearby map follows the system dark mode (the rest of the app is light).
- Local SQL checks: `supabase/tests/run_beta_local.sh`.

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

An alumni-to-alumni marketplace, the **Market** tab. No checkout, nothing is
charged in the app. Every marketplace screen shows a short notice that payment
is between buyer and seller.

- Anyone can browse live products. Only the owner of an **approved
  business** can post, up to the free limit of the business's band.
- Products from an approved business go live at once. Admins can still
  reject or hide a product, and anyone can report it. A suspended business
  hides its products.
- Buyers use the seller's shop link and/or contact info. There is no in-app
  checkout or messaging link.
- Anyone can report an approved listing (spam, prohibited item, misleading,
  other). Admins see report counts per listing. People can also be blocked
  (Profile > Blocked users).

**Files:** migrations `supabase/migrations/20260930*_marketplace_*.sql`,
seed `supabase/seed_marketplace.sql`, SQL checks in `supabase/tests/`,
Dart in `lib/{models,data,screens}/marketplace_*`, tests in `test/`.

**Run the demo database.** Do NOT apply these migrations to the shared live
project the `main`/`demo` branches use. Use a separate project or a
Supabase branch database, then apply the four `marketplace_*` migrations in
order, `seed.sql`, then `seed_marketplace.sql`. The seed is idempotent
(fixed ids, safe to run twice) and makes the profile
`demo.admin@example.com` the demo admin. To add another admin, insert
its profile id into `marketplace_admins` from the dashboard.

**Admins.** The old admin passphrase is gone. Admins are rows in
`app_admins` (migration `20261003130000`). See the header of that file for the
SQL that adds an admin by email. Because there is no real login, an admin
action is still only as safe as knowing the admin's profile id. See
`SECURITY_AUDIT.md`, "Known gaps for the closed beta".

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
- There is no subscription any more. Job posting needs a verified poster
  (migration `20261003090000`). Apply it together with the new app build,
  or posting jobs breaks.
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
Home, Directory, Market, Profile (Chat only returns if `chatEnabled` in
`lib/config/feature_flags.dart` is turned on). Jobs, News ("See all
announcements"), Requests, Notifications and Nearby open from Home with a back
arrow.

**Upcoming Preview tiles.** Events, Mentoring and Business directory are
non-functional tiles marked "Preview". Tapping one only opens an info sheet.
No data, no dates, no tracking, no money features.

**Lock screen (Android and iOS only).** After the first successful
verification the app remembers, on that device only, the profile id, a
display name and a masked email hint (`s***@example.com`), all in the
platform secure storage (Keychain / Keystore). It then offers a 6-digit PIN
(and fingerprint or face, if the device has it). On the next launch a
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
- "Forgot PIN? Verify again", "Not you? Switch account" and Profile > Sign
  out clear the local data only. Nothing is deleted on the server.
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
launch theme, and iOS needs `NSFaceIDUsageDescription`; these are set but
have not been built for either platform here. A PIN of 6 digits can be
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
