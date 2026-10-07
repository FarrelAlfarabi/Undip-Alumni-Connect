# Open items (6 Oct 2026)

What is not finished, who has to act, and why it is waiting.

## Needs you
| Item | Why only you | Where |
|---|---|---|
| Fill the operator name, contact email and address | A legal contact cannot be invented. The CI APK job fails until you do | `lib/config/policy_config.dart` |
| Push the branch | The push was blocked in the cloud session | `git push -u origin claude/gracious-edison-clv6vt` |
| Make the repo private (and decide on history) | GitHub setting. History still has three real addresses | `docs/BETA_RULES.md` step 6 |
| Apply the two migrations to a separate test project, run the live checks | Needs your Supabase access. Not to the live project first | `20261005090000`, `20261005100000`, `supabase/checks/live_db_checks.sql` |
| Check which versions the live project recorded, then delete one copy of each duplicate marketplace migration pair | Wrong choice breaks `db push` | `20260930052*` vs `20260930090*` |
| Real phone test | Needs a phone: first run, back button, feedback button, airplane mode | `docs/BETA_RULES.md` step 8 |
| Release signing and application id | Needs your keystore | `android/app/build.gradle.kts` |
| Send the beta message | Fill the brackets | `docs/BETA_MESSAGE.md` |
| Legal items | Terms and Indonesian Terms in app, breach plan, electronic system operator registration, data processing agreements, written permission from Ikafe for the member list | `docs/LEGAL_AUDIT.md` |

## Waiting for real login (do these after, or you write them twice)
`docs/AUTH_MIGRATION_PLAN.md` has the order and the rough size (3 to 4 weeks, my guess).
- Everything where the client sends a profile id: delete account, applications, contact requests, blocks, reports, admin, businesses, marketplace.
- Directory still returns email and NIM to everyone. CVs are in a public bucket.
- Job edit and close, "set my own city" (the database locks city for the app, so both need a new function that trusts a client id today).
- Applicant status, account deletion leaving other people's CV files and applicant names in `email_log`.
- Anyone can request contact again after an accepted request.

## Small and safe, not done yet
- Home fetches every approved listing to show three.
- Notifications list has no limit.
- Nearby only knows 8 cities.
- No tests for post job, apply, applicants, profile edit.
- Announcements list shows no dates.
- Marketplace admin "Reports" tab duplicates the new admin Reports.
- Push notifications (needs a Firebase project). No real email is sent.

## Older sessions (summaries only, check before relying)
- `feature/production-hardening` (auth, RLS, realtime) and `feature/ai-job-description` (Gemini): not on the remote any more; no Gemini code in the repo.
- `chore/sync-migrations` Stage 2: not on the remote any more.
- Settings tab with subscription and dark theme: not in this build.
