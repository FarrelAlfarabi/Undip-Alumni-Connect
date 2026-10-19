# Stage log

Older stages (0 to 8): docs/archive/STAGE_LOG_ARCHIVE.md

If a session ends early, continue from the last entry here.

## Feature intro (19 Oct 2026)
- New `FeatureIntroScreen`: 2 skippable pages explaining Marketplace (Market > Products) and Business (Market > Businesses). Copy in Indonesian, feature names in English.
- `IntroGate` wraps the app in `defaultHomeBuilder`; shows the intro once per person per device (flag in the lock store, `LockService.introSeen/markIntroSeen`). Web build shows it once per page load.
- Settings > "Pengenalan fitur" reopens it. Independent of the profile-setup PR. No SQL change.
- Checks: analyze clean, full suite passes (`test/feature_intro_test.dart` new).

## Stage 9: docs and PR
- Updated `PROJECT_NOTES.md` (new entry), `README.md`, `DEMO_SCRIPT.md`, `MARKETPLACE_CHECKLIST.md`, `docs/hub/CLICK_TEST_CHECKLIST.md`. Added section 11 "Known gaps for the closed beta" to `SECURITY_AUDIT.md`. The master plan was not touched.
- PR description written (migration order, secrets, admin SQL, "I must fill in", decisions, gaps, warning). PR marked ready for review. Not merged. Vercel not touched.
- Final checks: analyze clean, all tests pass, beta SQL checks pass (run at Stage 7).

## Stage 8B: layout stress tests
- New `test/layout_stress_test.dart`: about 25 screens (normal, empty, error states) at 320x568 text 1.0 and 360x640 text 1.6, Nearby map in dark mode, tap targets of at least 48 dp and tooltips on icon buttons. Uses Roboto from the Flutter SDK (the default test font is far too wide and gives false overflows).
- Result: no failures at those sizes. A stricter check at 320 wide with text 2.0 found two real problems, both fixed: the consent screen's bottom panel (Continue could be cut off) now scrolls, and the policy banner and language switch now scroll with the text; the status chip on My businesses can shrink.
- Not covered: InkWell tap areas, popup menus, SegmentedButton; real IBM Plex Sans (slightly wider than Roboto); real phones.
- Checks: analyze clean, 535 tests pass. No SQL change.

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
