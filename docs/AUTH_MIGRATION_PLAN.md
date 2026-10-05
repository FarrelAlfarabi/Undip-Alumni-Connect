# Auth migration plan

Goal: replace "type an email and you are that person" with a real login, so the
database knows who is calling. Until this ships, every anonymous function in the
app can be called as anyone by a person holding the public app key. The beta
hardening changes (verification lock, closed tables) only make that harder. They
do not close it.

## Why the first attempt failed (so we do not repeat it)

- The database side was built first: `claim_alumni_profile()`
  (`20260922024915_add_auth_claim_function.sql`) and a rewrite of the RLS rules
  (`20260922025148_rewrite_rls_real_auth.sql`).
- It was applied to the shared live database while the app still had no login
  session. Every app call arrived as anon, matched no policy, and silently did
  nothing (edit profile, post a job, messages).
- The fix was to add open anon policies back (`20260922120000_restore_anon_write_access.sql`).
  Those policies are still there and are why the database is open today.

Rules for this time:
1. Build and test on a separate Supabase project (or a Supabase branch). Never first on the shared live one.
2. The app change and the database change for one feature ship in the same release.
3. Each feature has an attacker test before it is switched over: call it as person B using person A's id, and it must fail.
4. Old anon access for a feature is removed in the same migration that moves the app off it, not later.

## Design

- Sign in with email OTP (`signInWithOtp` then `verifyOTP`). Free in Supabase. It proves the person owns the inbox.
- After sign in, `claim_alumni_profile()` links `auth.uid()` to the one `alumni_profiles` row whose email matches the signed in email (case insensitive, not deleted, not already claimed by someone else). It already exists and matches this design. Review it, do not trust it.
- `verification_status` stays set by the server only. It becomes "the signed in email matched the Ikafe list".
- Every function stops taking a profile id from the client. It reads the caller with `auth.uid()` and looks up the profile id itself. Where a parameter must stay for compatibility, the function ignores it.
- All grants to `anon` are removed from feature functions. Only the sign in calls stay open.

## Order, by how much damage each hole allows

Estimates are my rough guess for one developer working with Claude, using test first. Replace them with your own after the first step.

| Step | What moves to `auth.uid()` | Why this order | Rough size |
|---|---|---|---|
| 0 | Separate Supabase project with fake data, SQL tests in CI | Needed before anything else. Fixes the broken fresh install chain (`20260915061525`) | 1 to 2 days |
| 1 | Sign in screen (email OTP), `claim_alumni_profile()`, session handling in `AppEntry`, lock screen keeps working | Everything else depends on it | 3 to 5 days |
| 2 | `account_delete`, `account_files`, `account_accept_policy` | Anyone can delete anyone today. Irreversible | 1 day |
| 3 | Job applications: only the poster and the applicant can read; `cvs` bucket private with signed links; one application per person per job | Applicant phone, email and CVs are public today | 2 to 3 days |
| 4 | Admin functions: `app_admin_assert` uses `auth.uid()`; remove `is_app_admin(uuid)` and `marketplace_is_admin(uuid)` as public lookups | Today admins can be found and used by id | 1 to 2 days |
| 5 | Contact requests, blocks, reports, feedback, notifications | Shared contacts and block lists are readable by id today | 3 days |
| 6 | Businesses and marketplace: owner and seller come from `auth.uid()`; edits of approved products go back to review; seller contact info only after the "Contact seller" tap | Listing hijack and posting as someone else | 3 to 4 days |
| 7 | `alumni_profiles`: update only your own row; directory returns only the columns a screen needs (no email or NIM for other people); remove `alumni_profiles_update_anon` and `job_posts_insert_anon` | Closes the directory dump | 2 to 3 days |
| 8 | Final audit: re-run `supabase/tests/security_audit/probes.sql`, `supabase/checks/live_db_checks.sql`, and an attacker test per function. Then flip `chatEnabled` only if wanted | Proof that the doors are shut | 2 days |

Total: about 3 to 4 weeks. If testers have real data before step 7, tell them
plainly what is still exposed (see `docs/BETA_RULES.md`).

## Per step checklist (copy for each step)

- [ ] Attacker test written first and fails against today's code (person B acts on person A's id)
- [ ] Migration written, with a rollback file and the SQL test in `supabase/tests/beta/`
- [ ] App change in the same branch, with a widget test
- [ ] `supabase/checks/live_db_checks.sql` updated with a row for the new state
- [ ] Applied to the separate project first, clicked through on a real phone
- [ ] Release notes tell testers whether they must sign in again

## What testers will notice

- One more screen: enter email, type the code from the inbox. Once per device, then the PIN lock as today.
- Old installs stop working at the step 1 release. Tell testers to update first.

## Decisions I need from you

1. Is there an email on file for every alumnus in the Ikafe list? OTP only works if the inbox is real and the same address.
2. Who owns the Supabase project (billing and email sender settings)? OTP emails need a sender that does not land in spam. The default sender is rate limited.
3. Do you want the directory to stop showing NIM and email to other alumni, or is that intended?
