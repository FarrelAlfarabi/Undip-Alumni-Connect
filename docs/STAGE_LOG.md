# Stage log

If a session ends early, continue from the last entry here.

## Stage 0: audit
- Wrote `docs/AUDIT_2026-10-03.md`.
- Checks: analyze clean, 232 tests pass, `run_job_gate_local.sh` passes. `run_local.sh` fails on a clean DB (old migration chain, known, documented in the audit).
- Could not verify: web build (not touched on purpose), live database.

## Stage 1: Android debug APK in CI
- Added a `build-apk` job (needs `analyze-and-test`), manual trigger, Flutter pinned to 3.47.4, `--build-number` = run number, 7 day artifact, optional fixed debug keystore.
- Checks: workflow YAML parses.
- Could not verify: the job running on GitHub (needs the secrets), a real APK install.

## Stage 2: PIN bug
- Cause: `signOutTo` wiped the PIN, and the unlock step wiped everything on any error (even no internet).
- Fix: PIN now has an owner id (`owner_id` key). `LockService.signOut()` forgets the person but keeps the PIN. `remember()` keeps the PIN only for the same person, else drops it. A network error on unlock keeps everything and shows a retry message. Profile gone or not verified still wipes. Switch account, Forgot PIN, 5 wrong PINs still `clear()`.
- Tests first: `test/lock/pin_survives_sign_out_test.dart` (new), `sign_out_test.dart` and one case in `lock_screens_test.dart` updated to the new rule.
- Checks: analyze clean, 242 tests pass.
- Could not verify: real secure storage on a phone.
- Old installs (PIN without owner key) keep the PIN for the remembered person, so no one is forced to set it again.

## Stage 3: remove subscription
- App: deleted `subscribe_screen.dart` and `marketplace_gate.dart`, removed the gates in job board, profile detail, marketplace. Jobs can be posted by any verified alumnus. "Post a listing" now shows a plain "Posting is not open yet" message (until Stage 6).
- Database: `20261003090000_remove_subscription_gate.sql` (+ `rollback_remove_subscription_gate.sql`). Job posts now need a VERIFIED poster (replaces the subscriber rule). `marketplace_create_listing` raises `posting_closed`. `demo_subscribe` is off (flag false, no execute right). Nothing dropped.
- New local SQL harness: `supabase/tests/run_beta_local.sh` (+ `supabase/tests/beta/`). It applies every beta migration twice, runs the tests as anon, runs rollbacks, re-applies.
- Checks: analyze clean, 244 tests pass, beta SQL checks pass.
- Could not verify: the live database. The migration must be applied together with this app build.
- Decision: a verified-poster check replaces the subscriber check on job_posts (kept some protection against anonymous inserts; reason: the old rule was the only DB guard on that table).

## Stage 4: hide chat behind one switch
- `lib/config/feature_flags.dart`: `const bool chatEnabled = false;`. When off: no Chat tab (3 tabs: Home, Directory, Profile), no Message button on profiles, no city group chat button on Nearby (WhatsApp invite stays). Chat tables and data untouched. The announcements feed stays.
- No notification links to chat today. Stage 6E will respect the switch too.
- `NearbyAlumniScreen` got an optional `fetchAlumni` so it can be tested without Supabase.
- Tests: `test/chat_switch_test.dart` (new), `home_shell_test.dart` updated for both switch states.
- Checks: analyze clean, 251 tests pass.

## Stage 5: business directory
- Database: `20261003100000_business_directory.sql` (+ `rollback_business_directory.sql`). Table `businesses` (owner, name, description, category, social_link, website_link, requested_band, approved_band, status, rejection_reason, unlimited_until, timestamps). The app has NO direct table access. It uses functions: `business_register`, `business_update`, `business_my`, `business_directory`. A column lock trigger is a second guard (status, approved_band, unlimited_until, rejection_reason, requested_band, owner_id cannot be set by anon). Links are cleaned (lower case, no scheme, no www, no query, no trailing slash) and a link already used by another business, in either link column, is refused.
- App: registration form (four bands with Rp amounts, at least one link, band chosen once), My businesses (status, rejection reason, edit and apply again), searchable Businesses directory (name, category, category chips) for verified alumni, business detail with links. Home: a real "Businesses" tile replaces the Business directory preview.
- Tests first: `supabase/tests/beta/02_business_directory_test.sql` (anon role: no direct select/insert/update, self-approval impossible, link rules, owner rules, directory visibility, trigger guard with a deliberately added grant and policy) and `test/business_directory_test.dart`.
- Checks: analyze clean, 270 tests pass, beta SQL checks pass.
- Decisions: owner may edit only while pending or rejected (approved and suspended are locked, contact admin); at least one link is required; categories are the same five as the marketplace.
- Could not verify: the live database; the directory on a phone.

## Stage 6: marketplace products and limits
- Database: `20261003110000_marketplace_business_products.sql` (+ rollback). `posting_plans` (band, free_post_limit, monthly_price_idr; seeded micro/small/medium 3 and 25000, large 1 and 200000; editable in the dashboard; the app cannot read it). `marketplace_listings.business_id`. `marketplace_create_listing` now takes the business (old 9 argument signature dropped). Only the owner of an APPROVED business with an approved band can add a product. A product is approved at creation. The limit is checked in the function and by a trigger for any direct insert path. Unlimited if `unlimited_until` is today (Jakarta date) or later, else used < free limit of the approved band. Sold and deleted products do not count. Over the limit: everything stays visible, only new ones are blocked, edit and delete work. A suspended business hides all its products (select policy). `business_my_usage` feeds the owner card (no price). Old seed listings (no business) stay visible, count against nothing.
- App: "Add a product" flow (needs approved business, picks a business if there are several, shows used out of limit and a contact-admin message at the limit, no payment words), owner card shows approved band, used out of limit, unlimited until with days left, Contact info hint changed to "WhatsApp, phone, email, social media..." (label and 300 limit kept). Product form button is now "Post product".
- Tests first: `supabase/tests/beta/03_marketplace_products_test.sql` (anon role, limits, dashboard changes the limit, unlimited today and expired, suspended hides, direct insert path guarded) and `test/marketplace_products_test.dart`. Old marketplace tests updated.
- Decisions: edit of an approved business product stays approved (no review); rejected ones go back to pending. A product an admin rejects still counts toward the limit until deleted (status is not "sold"). Admin "reject an approved product" comes with the admin migration (Stage 6C).
- Checks: analyze clean, tests pass, beta SQL checks pass.

## Stage 6B: request to contact
- Database: `20261003120000_contact_requests.sql` (+ rollback). `contact_requests` (requester, target, message max 200, status, shared_contact max 200, timestamps). No direct table access for the app. Functions: send, incoming, outgoing, pending_count, respond, shared_contact. `shared_contact` is never in a list, and is released only by `contact_request_shared_contact` when status is accepted and the caller is the requester. A trigger enforces: not yourself, one open request per pair, 5 new requests per requester per Jakarta day, 30 day cool-down after a rejection. The dashboard is not restricted and can read everything.
- App: "Request to contact" on other people's profiles (not on your own), optional message (200), Requests screen (Received and Sent), accept requires typing what to share (200), rejected shows only "Not accepted", shared contact shown only after accept and a tap, Home app bar Requests icon with a badge of waiting requests.
- Tests first: `supabase/tests/beta/04_contact_requests_test.sql` (anon role) and `test/contact_requests_test.dart`.
- Checks: analyze clean, 294 tests pass, beta SQL checks pass.
- Honest limit (also in docs/DECISIONS.md): without real login this is a speed bump, not security.

## Stage 6C: admins without passphrase
- Database: `20261003130000_app_admins.sql` (+ rollback). `app_admins` (profile_id unique, added_at, note; the app cannot read or write it). `is_app_admin(profile)`. The old passphrase functions (`marketplace_admin_pending`, `marketplace_review_listing`, `marketplace_report_counts`, `marketplace_is_admin`) now check `app_admins` and ignore the passphrase. New `admin_businesses_list` and `admin_business_decide`. Business reviewer columns added. Nobody is made admin in the migration. The SQL to add Gilang and Maria is a comment at the top of the migration (and in the PR description).
- App: no passphrase prompt. Profile shows "Admin" only when `is_app_admin` is true (asked once per session, never cached on the device). Admin screen with Businesses (pending first, approve with the band chosen from the four, reject with reason, suspend, restore) and the old Marketplace review queue. The admin icon in the marketplace app bar is gone. Reports (6D) and Feedback (6F) are added to the admin screen by their stages.
- Tests first: `supabase/tests/beta/05_app_admins_test.sql` (anon role: app cannot read app_admins; non-admin refused on every admin function; the old passphrase is refused; an admin works; unlimited_until untouched) and `test/admin_test.dart`. The old passphrase widget tests were removed.
- Checks: analyze clean, 300 tests pass, beta SQL checks pass.
- Note: `supabase/tests/run_local.sh` and the old `marketplace_rls_test.sql` still assume the passphrase system and the old marketplace create function. They did not run on a clean database before this work either (see the audit). The new harness is `run_beta_local.sh`.

## Stage 6D: reporting and blocking
- Database: `20261003140000_reports_and_blocks.sql` (+ rollback). `content_reports` (job, product, business, profile, contact_request; five reasons; note max 300; open, actioned, dismissed). Enforced in the database: verified reporter, not your own content, one open report per target (also for any direct insert path). `hidden_at` / `hidden_reason` on `job_posts`, `businesses`, `marketplace_listings`. Hidden content leaves every public list (policies and functions). Hiding a business hides all its products. `user_blocks` with `user_block`, `user_unblock`, `user_blocks_list`. Blocked people cannot send contact requests to the blocker (trigger), open requests between the pair are closed. `business_directory` leaves out hidden businesses and blocked owners. Admin: `admin_reports_list` (open reports with counts and reasons, marketplace reports included, or the hidden list) and `admin_reports_decide` (dismiss, mark handled, hide, restore).
- App: Report sheet (reason picker, note, thank you), Report and Block menu on job detail, business detail, profile detail and each received request; products keep their Report button and get a Block entry. One shared helper `BlockList` filters Directory, Nearby, Job board, Home latest jobs and products, Marketplace and Businesses. Blocked users screen (Profile > Blocked users). Admin Reports screen. Owners see "Hidden by an admin" on their business and product cards.
- Tests first: `supabase/tests/beta/06_reports_and_blocks_test.sql` (anon role) and `test/reports_blocks_test.dart` (every list, every menu).
- Checks: analyze clean, tests pass, beta SQL checks pass.

## Stage 6E: notifications
- Database: `20261003150000_notifications.sql` (+ rollback). New columns on `notifications`: `type`, `target_type`, `target_id`, `actor_id`, `event_key` (unique). Only `notify_create` (internal) writes rows. Triggers create: contact request received (target), accepted (requester), business pending (every admin), business approved, rejected with reason, suspended, restored (owner), job, product or business hidden with reason (owner), new report (every admin, content and marketplace reports), job application (poster, existing trigger now typed, still honours notify_on_apply and the simulated email). Suppressed for your own action and for a person the receiver blocked. The anon role cannot insert, delete or change anything except `read_at`.
- App: Notifications screen (newest first, marks read when opened, new ones highlighted, empty state, error with Try again, tapping opens Requests, My businesses, My listings, the admin screens, or the applicants; a friendly message when the job is gone or hidden). Bell with unread badge in the Home app bar. The old bell on the Job Board is removed. Anything that links to chat is hidden while `chatEnabled` is false. No push.
- Also fixed: several `setState(() => _future = ...)` calls returned a Future (a debug assertion); they now use a block body.
- Tests first: `supabase/tests/beta/07_notifications_test.sql` (exactly one row per event, no duplicates, blocked senders suppressed, anon insert rejected) and `test/notifications_test.dart`.
- Checks: analyze clean, 351 tests pass, beta SQL checks pass.

## Stage 6F: feedback on errors
- Database: `20261003160000_feedback_reports.sql` (+ rollback). `feedback_reports` (profile id nullable, message max 500, error_text max 300, screen max 60, app version, build number, platform, status new/seen/done). The app role can only INSERT (no read, no update, no delete, no returning). 10 per profile per day by trigger; the database sets `created_at`. Admins use `admin_feedback_list`, `admin_feedback_new_count`, `admin_feedback_set_status` (checked against `app_admins`).
- App: `cleanErrorText` (emails, keys, tokens, URLs, phone and long numbers, ids, stack traces removed; max 300). One shared `ErrorView`, `InlineError` and `showErrorSnackBar`, used on every load error screen, every failed form submit and the error snackbars, each with Send feedback (and Try again where there is one). Feedback sheet: plain line about what is sent, optional "What were you doing?", thank you; on failure it says so and offers Copy details. Version comes from `AppInfo` (package_info_plus), the same place the About screen will use. Admin > Feedback (newest first, new count, mark as seen or done) with a badge on the Admin screen.
- Tests first: `test/error_report_test.dart` (cleaning, with email, key and phone samples), `supabase/tests/beta/08_feedback_reports_test.sql` (anon can insert but not read, daily limit, back-dating), `test/feedback_test.dart` (error screen button, send success and failure, copy, admin screen).
- Checks: analyze clean, 376 tests pass, beta SQL checks pass.
- Added dependency: `package_info_plus`.

## Stage 6G: account deletion, privacy policy, consent
- Database: `20261003170000_account_deletion_and_consent.sql` (+ rollback). `alumni_profiles.policy_version`, `policy_accepted_at`, `deleted_at` (locked from direct app edits), `nim` now nullable. Select policy hides deleted rows. `account_accept_policy`, `account_files`, `account_delete` (one transaction: businesses, products, jobs, applications, contact requests both ways, notifications to and from, blocks both ways, feedback, simulated emails, chat messages, admin rows; reports kept without their note; profile cleared and marked deleted). `storage_cleanup_queue` for the files the app cannot remove.
- App: privacy policy and community rules (two asset files, Indonesian first then English, version constant, last updated date, draft banner; operator name and contact email placeholders in one config file); consent screen (checkbox, Continue, back and sign out) shown after verification or unlock only when the accepted version differs; Delete my account (plain explanation, type HAPUS or first name, final confirm, files removed best effort, then the device is wiped and Welcome is shown). Profile has entries for the policy and for deleting the account.
- Tests first: `supabase/tests/beta/09_account_deletion_test.sql` (function result, constraints, hidden from lists, cannot verify again, restore from the dashboard) and `test/account_test.dart` (policy text, consent gate for not accepted, accepted and changed version, device wipe, storage failure).
- Checks: analyze clean, 401 tests pass, beta SQL checks pass.
- Could not verify: real storage removal, the real secure storage wipe on a phone.

## Stage 7: navigation and Home
- 4 tabs: Home, Directory, Market, Profile (Chat tab replaced by Market; Chat returns as a 5th tab only if `chatEnabled` is turned on). Market has two segments, Products and Businesses. Back from any tab goes to Home first. Home tiles Marketplace and Businesses switch to the Market tab on the right segment. Jobs, News, Nearby, Requests and Notifications stay reachable from Home.
- Home: business owner card (status, band, products used out of limit, unlimited days left), "Register your business" card for people with no business, Requests badge, notification bell with badge. A failed business load shows no card and does not block Home.
- Profile list: My business, Blocked users, Privacy policy and community rules, Admin (admins only), Delete my account (last).
- No subscription code or chat entry points remain in the default app.
- Tests: `test/stage7_test.dart` (new), `home_shell_test.dart` updated.
- Checks: analyze clean, 417 tests pass.

## Stage 7B: app version and BETA label
- `pubspec.yaml` version is now `0.9.0+1` (CI overrides the build number with the run number).
- Profile > About (new `about_screen.dart`, key `profile-about`) shows "Lingkaran v0.9.0 (build N) BETA". Welcome screen shows "BETA · v0.9.0 (build N)" under the closed beta line.
- Both screens and the feedback reports read the version from `AppInfo` (package_info_plus), so there is one source.
- Tests first: `test/stage7b_test.dart` with mocked package info (pubspec version, About, Profile row, Welcome, feedback report version).
- Checks: analyze clean, 422 tests pass. No SQL change.
- Could not verify: the real build number on a phone (needs the CI APK).

## Stage 7C: dark mode for the Nearby map
- The map has no map package and the app has no dark theme, so only the painted map follows the system brightness. New `MapPalette` (light and dark) for land, water, water line, avenues, grid, city label text and halo, marker ring. Markers keep the theme fill with white initials; the ring turns light grey on the dark map.
- Not changed: the rest of the Nearby page stays light (no app dark theme). Search box, buttons and popups are on that light page, so their contrast is unchanged.
- Tests: `test/nearby_map_dark_test.dart` (light and dark pump, label color, contrast numbers for labels, markers and initials).
- Checks: analyze clean, all tests pass. No SQL change.
- Could not verify: how it looks on a real phone in dark mode.

## Stage 8: UX review
- Full review of every screen (code reading, not tested on a real phone): `docs/UX_REVIEW.md`, 41 rows with severity and fix. 7 High.
- Fixed (High, small, low risk): the marketplace banner now says "Lingkaran does not handle payments or delivery. Deal directly with the seller and check before you pay." (the constant `MarketplaceDemoNotice.text` stays, tests read the new text); Verify and Welcome copy no longer says demo, dummy data or sample accounts; a wrong email no longer clears the field on Try again; Profile has a "Send feedback" row so testers can report a confusing screen without an error.
- Left open (High): placeholders in the policy (you must fill them in), no proof of email ownership (needs real login), Nearby has no way to add a city, Requests card shows only a name (both medium effort).
- Tap targets: the only compact items are display chips, buttons use Material defaults (48 dp). No change needed.
- Tests: `test/stage8_test.dart`; the Visit shop test now scrolls to the button because the banner is two lines.
- Checks: analyze clean, all tests pass. No SQL change.

## Stage 9: docs and PR
- Updated `PROJECT_NOTES.md` (new entry), `README.md`, `DEMO_SCRIPT.md`, `MARKETPLACE_CHECKLIST.md`, `docs/hub/CLICK_TEST_CHECKLIST.md`. Added section 11 "Known gaps for the closed beta" to `SECURITY_AUDIT.md`. The master plan was not touched.
- PR description written (migration order, secrets, admin SQL, "I must fill in", decisions, gaps, warning). PR marked ready for review. Not merged. Vercel not touched.
- Final checks: analyze clean, all tests pass, beta SQL checks pass (run at Stage 7).
