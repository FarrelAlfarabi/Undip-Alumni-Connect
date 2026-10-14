# Real login (emailed code): built, switched off

Status: code and SQL are finished and tested locally. Nothing is applied to
Supabase and nothing is switched on. Replaces the email-only "verify" step.
Background and the earlier plan: `docs/AUTH_MIGRATION_PLAN.md`.

## What a person sees
1. Types their alumni email, taps Verify. No record on file: "No Matching
   Record", no email is sent.
2. Gets a 6 digit code by email, types it, taps Verify code.
3. Then the same steps as today: policy consent, optional PIN, app.
4. The PIN still locks the app on the device. If the stored sign in is gone
   (expired, signed out), the PIN is not enough and they sign in again.

## What it protects
With the switch on, a person can only act as themselves. Before, the app sent
a profile id with every call and the database believed it. Now:
- Every function that took an id from the app (businesses, listings,
  contact requests, reports, blocks, notifications, account delete, ...)
  refuses unless the caller is signed in as that profile.
- Admin checks require the caller to BE the admin. Knowing an admin's profile
  id is no longer enough.
- The open (anonymous) write policies on profiles, jobs and chat are removed.
- The old email-only check no longer works for the app.

## Pieces
| Piece | File |
|---|---|
| App flag, off by default | `lib/auth/login_api.dart` (`REAL_LOGIN`) |
| Code screen | `lib/screens/verification_screen.dart` |
| Sign out / expired sign in | `lib/lock/session.dart`, `lib/lock/app_entry.dart` |
| Database part, safe to apply early | `supabase/migrations/20261013120000_real_login.sql` |
| The switch (run by hand) | `supabase/cutover_real_login.sql` |
| Undo the switch | `supabase/rollback_cutover_real_login.sql` |
| Undo the migration | `supabase/rollback_real_login.sql` |
| Vercel build flag | `REAL_LOGIN=true` env var in `scripts/vercel-build.sh` |

The migration alone changes nothing for users: `app_settings.require_login`
starts as `off`, and every added check passes while it is off. So it can be
applied before the new build ships.

## Go live checklist (in this order)
1. Supabase, Authentication:
   - Email sign in on, "Confirm email" on.
   - Email template (Magic Link and Confirm signup): show `{{ .Token }}` so
     the email contains the 6 digit code, not only a link.
   - Set a real SMTP sender (Resend, Brevo, SES, ...). The built in sender is
     limited to a few emails per hour and will fail once testers sign in.
   - Set OTP length to 6 and expiry to 600 seconds (default is 1 hour; the
     dashboard setting could not be read from here). The login screen says
     "expires after a while" so it stays true whatever you choose.
2. Apply `20261013120000_real_login.sql`. Check: `select * from app_settings;`
   shows `require_login | off`.
3. Deploy the app built with `REAL_LOGIN=true` (Vercel env var, or
   `flutter build ... --dart-define=REAL_LOGIN=true`). Test on a phone with
   your own alumni email: code arrives, sign in works, admin screens work.
4. Add real admins to `app_admins` as before (see the 20261003130000 notes).
5. Run `cutover_real_login.sql`. From this moment the OLD app build stops
   working. Roll back with `rollback_cutover_real_login.sql` if needed.

## Not covered (be honest with testers and yourself)
- Alumni whose email changed cannot get a code. Fix by hand: update their
  email in `alumni_profiles`.
- Anyone with access to an alumnus's mailbox can sign in as them. That is
  normal for email code login.
- Tables the app reads directly (for example the alumni directory) are still
  readable by the anonymous role. This work scopes WRITES and the identity
  based functions, not reads. Check `supabase/checks/live_db_checks.sql`.
- Storage buckets still accept uploads from the anonymous role.
- Deleting an account removes the alumni data but not the Supabase Auth user
  row. Remove it in the dashboard if someone asks.
- The first sign in links the auth user to the alumni row by email. If two
  alumni rows share an email, the first match wins.
- Not tested against real Supabase Auth or real email delivery. Everything
  here was tested with stand-ins (local Postgres with a fake `auth.uid()`,
  fake app login API).
