# Closed beta rules

Read this before you send the app to anyone. Two parts: what the operator does,
and what testers are told.

## The honest state

There is no real login yet. The database cannot tell who is calling. Anyone who
gets the app (the debug APK or the web build) also gets the public key inside it,
and with that key can read or change more than the app screens show. The beta
hardening changes close the worst holes. The rest closes with
`docs/AUTH_MIGRATION_PLAN.md`.

Still open after the hardening, in plain words:
- Anyone with the key can read every profile, including email and NIM.
- Anyone with the key can act as another person in most features (request contact, report, block, post a job, apply, delete an account).
- Job applications (name, email, phone, cover note) can be read by anyone with the key, and uploaded CVs are public files.
- Contact details shared after an accepted request can be read by anyone with the key.

So: test data only, and a small list of people you know.

## Operator checklist (before the first tester installs)

1. Fill in the operator name, contact email and address in `lib/config/policy_config.dart`. The CI APK job fails until you do (`test/release_check_test.dart`).
2. Use a Supabase project with fake or minimal data for the beta. Do not import the real alumni list (email, NIM) until login exists.
3. Apply the new migrations to that project with the matching app build, in this order:
   - `20261005090000_lock_verification_status.sql`
   - `20261005100000_close_anon_reads.sql`
   The old app build stops working after them (it verifies with an UPDATE and reads tables that are now closed). Tell testers to update first.
4. Run `supabase/checks/live_db_checks.sql` in the Supabase SQL editor. Every row must say `true`. Fix any `false` before sending the build. Pay attention to "old job_posts subscriber trigger is gone": if it says `false`, nobody can post a job.
5. Send the debug APK to named people only. Do not publish the web URL.
6. Make the repository private. The demo seeds no longer carry real names or addresses, but the git history still does. If the repo was ever public, assume those three addresses were seen. To remove them from history you must rewrite it (for example with `git filter-repo`), which changes every commit id. That is your call.
7. You are the only admin. Add yourself with SQL (see the header of `supabase/migrations/20261003130000_app_admins.sql`). Remove the demo admin row if you applied `seed_marketplace.sql`.
8. Real device test before sending: first run, back button, an error then "Send feedback", airplane mode.

Chat stays off. Its tables are closed to the app key on purpose. If you ever flip
`chatEnabled` to true, run `supabase/rollback_close_anon_reads.sql` first, and
understand that this opens every chat message to anyone with the key again.

## What testers are told

Copy this into the message that comes with the APK:

- This is a closed test. Please use test contact details.
- Do not upload a real CV. Use a dummy file.
- Do not enter a real phone number. Use a made up one.
- When you accept a request to contact, share only what you would put on a public profile.
- Do not share the app file or the link with anyone.
- If something fails, tap "Send feedback" on the error. If that does not work, send a screenshot to the contact email.
- You can ask for your account to be deleted at any time by writing to the contact email.

## Why account deletion is manual in the meantime

The in-app delete button works, but anyone with the key can also delete any
account. Until login exists, treat it as a feature for testers to try on test
accounts. Real deletion requests go to the contact email and are done by you in
the dashboard.
