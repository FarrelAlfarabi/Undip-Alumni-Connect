# UNDIP Alumni Connect — MVP demo

Flutter + Supabase demo of a verified alumni directory with a job referral
board, subscription-gated messaging, and an ILUNI announcements feed.
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

Row Level Security is **off** on every table. That is a deliberate
demo-scope decision and means the anon key can read and write everything.
Do not reuse this project or key for anything beyond the demo.
