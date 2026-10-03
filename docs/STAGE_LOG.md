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
