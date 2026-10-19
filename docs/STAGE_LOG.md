# Stage log

Older stages (0 to 9): docs/archive/STAGE_LOG_ARCHIVE.md

If a session ends early, continue from the last entry here.

## Beta hardening (6 Oct 2026), after the build review
Everything test first. Dart: analyze clean, all tests pass (2 skipped, the release gate). SQL: `run_beta_local.sh` and the new `run_fresh_chain.sh` pass.
- Main Android manifest now has INTERNET (release builds could not reach the network).
- `verification_status` is set only by `verify_alumni_email()`; the app cannot write it (migration `20261005090000`).
- `email_log`, the chat tables and `notifications` are closed to the public key; notifications are read through three functions that return no `recipient_id`, `actor_id` or `event_key` (migration `20261005100000`). The simulated email screen is gone.
- The "Send feedback" action on error snackbars threw "context does not include a Navigator" and opened nothing. Fixed; the test now taps it.
- Release gate: the CI APK job fails while `lib/config/policy_config.dart` still says `[FILL IN]`.
- `supabase/checks/live_db_checks.sql`: read-only checks to run against the live project.
- A fresh database now builds from all 41 migrations (two old revokes were conditional-ised; the local stub got the realtime publication). CI has a `sql-checks` job and runs on pushes to main; Vercel uses the same Flutter version as CI.
- Seeds, tests and docs carry no real names or personal addresses. Git history still does.
- Directory and Market refetch when you enter the tab; blocking someone refreshes every tab.
- PIN lock: Profile > PIN lock sets, changes or removes the PIN (needs the current PIN).
- Apply "Done" no longer promises a status. Account deletion: database first, files after; `not_found` on retry counts as deleted.
- Web: `lang="en"`, semantics on at start-up.
- Closed test notice on Welcome and the consent screen.
- New docs: `BETA_RULES.md`, `AUTH_MIGRATION_PLAN.md`, `BETA_MESSAGE.md`, `OPEN_ITEMS.md`.
- Not done, on purpose: see `docs/OPEN_ITEMS.md`.

## Four fixes (16 Oct 2026)
- Business form: Instagram required (`@username` becomes an instagram.com link), website optional. Migration `20261016090000` makes `business_register` / `business_update` refuse a missing Instagram; not applied to any project. Old website-only rows are untouched.
- Admin: Businesses (search name, owner, link + category) and Feedback (search + status). Directory Industry: type to narrow or open the list. Web: viewport meta stops the focus zoom.
- Checks: analyze clean, 681 tests pass, `run_beta_local.sh` passes.

## Profile card redesign (16 Oct 2026)
- Academic and Employment are now two soft panels with an icon and title. Label sits above its value. Edit sits in the Employment header, at the panel edge. Larger avatar. Analyze clean, 681 tests pass.

## iPhone zoom guard (16 Oct 2026)
- The viewport meta alone did not stop an iPhone zooming into the business form and staying zoomed (Farrel's video). Added `web/viewport_guard.js` (blocks pinch, snaps back to 100% after a field loses focus or the page is zoomed) and `touch-action: manipulation`.
- Not reproduced here (no iPhone): the editing field is already 16px in a desktop Chromium run. Needs a real-iPhone check on the preview.

## Terms scroll gate (18 Oct 2026)
- Consent screen: the checkbox stays off until the policy is scrolled to the bottom, with a hint line. Short text that fits on screen unlocks at once. Stays unlocked after switching language. Policy text unchanged.
- Tests: `consent_scroll_test.dart`; `account_test.dart` scrolls first. Analyze clean, 686 tests pass.
## Reports search and filters (18 Oct 2026)
- Admin Reports: search (title, owner, note, reason) plus Type and Reason filters, on both Open and Hidden. Runs on the loaded list, no new load. Reason filter is hidden on the Hidden tab (those rows carry no reasons).
- Period filter (All time, Today, 7, 30 days) on Reports and Feedback. Removed the "new" tags: count badges on Admin Reports/Feedback and the Profile Admin row, the "N new of M" line, the highlighted border and status chip on new feedback. Reports no longer marks itself seen on open (data and SQL untouched). 690 tests pass.
- Admin Businesses: the status chips are now a Status dropdown next to the search; Category is type-to-filter (like Industry); new Posted filter (All time, Today, 7, 30, 90 days) by post date.
- Business form: photo helper now states the real limits (JPG/PNG/WebP, 2 MB, any size, cropped to a wide banner). Nothing in code or storage limits dimensions.

## Suspend user (18 Oct 2026)
- Reports: "Suspend user" on profile and contact-request reports (reason required), "Lift suspension" from the Hidden list. A suspended person cannot sign in (email match or email code), is gone from the Directory, and an already signed-in session is refused. Admins and yourself cannot be suspended. Their posts and businesses stay; hide those separately.
- Migration `20261018090000_suspend_user.sql` (rollback `rollback_suspend_user.sql`) is not applied to any project; it leaves the anon update policy alone if the real-login cutover dropped it. 704 tests pass, both SQL runners pass.
## Profile save fix (18 Oct 2026)
- Cause: DB trigger `alumni_profiles_restrict_update` still locked `city`; the editor sends city, so any city change failed. Not the Instagram migration (it only touches business functions).
- Migration `20261018100000_profile_city_editable.sql` (not applied to any project) + rollback + SQL test 16. App sends city only when changed and names the locked-field error.
- Checks: `run_beta_local.sh` and `run_fresh_chain.sh` pass. Flutter not installed in this session, so analyze and Dart tests run in CI only.
## Admin announcements (18 Oct 2026)
- Admin > Announcements: past posts with search and a Period filter (same `period_filter.dart` and components as Reports), plus a "New announcement" form (title 120, message 2000).
- Admin-only in the database: no write policy on `announcements`; posting goes through `admin_announcement_create`, which checks `app_admins`. Migration `20261018110000_admin_announcements.sql` is not applied anywhere. No Status filter: announcements have no status. No audience targeting.
## First-login profile step (18 Oct 2026)
- After the first consent only (policy_version was null), an optional screen offers the existing employment editor and Default contact; Lewati skips. No migration, no new fields, NIM not shown.
- Flutter not installed here: analyze and tests not run; CI must confirm.
## Contact request limits (19 Oct 2026)
- Already there: 5 per day, one open per person, 30 day wait after a rejection. Added: max 10 open requests at a time (`too_many_open`) and no new request to someone who already accepted you (`already_shared`), with plain messages.
- Migration `20261019100000` only replaces the insert guard; not applied to any project. Rollback script and SQL test `16` included.
