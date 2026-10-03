# Browser walk-through of the web build

The cloud sessions cannot reach Supabase, so this runs the Flutter **web** build
against a small fake backend and drives it in Chromium, taking a screenshot of
each screen (`shots/`, not committed).

`mock_backend.mjs` is an in-memory stand-in for the Supabase REST and Auth APIs
with seed data and the database triggers/functions the app relies on (new
application notifies the poster, status change notifies the applicant,
`claim_alumni_profile`, `update_job_post`, ...). It only understands what this
app sends.

```sh
# 1. a .env that points the app at the fake backend (gitignored)
printf 'SUPABASE_URL=http://localhost:54321\nSUPABASE_ANON_KEY=sb_publishable_uitest\n' > .env
flutter build web --release --no-web-resources-cdn

# 2. serve it, start the fake backend, run the walk-throughs
(cd build/web && python3 -m http.server 8080 &)
cd scripts/ui_test
npm install
node mock_backend.mjs &
node walkthrough.mjs     # sign in, job board, apply, edit/delete, post, notifications, retry
node walkthrough2.mjs    # first-time password, forgot password, directory, chat, profile, marketplace, small phones

# 3. put the placeholder .env back
cp ../../.env.example ../../.env
```

Seeded people: `rina@example.com` / `rina-pass-123` (has her own password),
`reza.putra@example.com` and the others use their NIM (`NIM` + the first 10 hex
digits of the id, see `mock_backend.mjs`) as the first password. `GET
/__reset` restores the seed data; `GET /__fail?on=1` makes every call fail, to
see the error screens.

Not covered: the PIN lock (off on web, covered by widget tests), real fonts
(Google Fonts is blocked in the sandbox, so Roboto is used), real Supabase
behaviour, and anything native (fingerprint, file picker).
