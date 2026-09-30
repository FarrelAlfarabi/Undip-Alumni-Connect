# UNDIP Alumni Connect — MVP demo

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

An alumni-to-alumni marketplace on the **Market** tab. **Demo only: dummy
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
- "Subscribers only" checks `subscription_status`, which any client can set
  (the demo Subscribe button does exactly that).
- Contact info on approved listings is readable by anyone holding the anon
  key, not only signed-in members.
- The `marketplace` image bucket allows uploads (images only, 2 MB) from
  anyone holding the anon key.
- Real enforcement needs real Supabase Auth (`auth.uid()`), which is a
  separate piece of work.

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
