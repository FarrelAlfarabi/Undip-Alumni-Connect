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

## Ikafe palette and logo (19 Oct 2026)
- Colors only: yellow `#FFC400`, black `#141414`, blue `#0073B1` (links) replace indigo and brass in `lib/theme.dart`. Filled buttons are yellow with black text; text links are blue; the lock screen is black.
- The Ikafe UNDIP logo (`assets/brand/`) sits on a white chip in the Home app bar, Welcome and lock screens. App title is "Lingkaran by Ikafe UNDIP". Layout unchanged.
- Tests: `test/brand_palette_test.dart` (AA contrast, theme mapping, logo placement). Analyze clean, 694 tests pass.
