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
