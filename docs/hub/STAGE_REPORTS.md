# Lingkaran home hub: stage reports and decisions log

Branch: `feature/home-hub` (created from `claude/beautiful-cori-mntun6`, the marketplace demo branch).
Newest stage at the bottom. The Decisions log is at the end of this file.

---

## Stage 0: Recon

**Status: DONE** (no code changes; only this file is committed)

### Environment
- `flutter` and `dart` were NOT installed in the session. I downloaded the stable SDK (Flutter 3.47.5, Dart 3.13.4, matches `sdk: ^3.13.3`) to `/opt/fl/flutter` (outside the repo). So `flutter analyze`, `flutter test` and `flutter build web` all run for real.
- Local Postgres 16 server binaries exist, so `supabase/tests/run_local.sh` can run (used in Stage 5).
- `.env` is gitignored and missing in a fresh clone; `pubspec.yaml` lists it as an asset, so analyze and tests fail without it. I made a local `.env` by copying `.env.example` (placeholder values, no real key). It stays out of git.

### Baseline (before any change)
- `flutter analyze`: no issues.
- `flutter test`: 80 tests, all pass.
- `flutter build web --release`: succeeds (about 65 s).

### Branch state
- Only `claude/beautiful-cori-mntun6` exists locally and on the remote. `main`, `demo`, `feature/production-hardening` and `feature/ai-job-description` are not present in this clone. I did not need them.
- `feature/home-hub` was created from the marketplace branch.

### Every screen reachable today
Entry: `main.dart` -> `WelcomeScreen` ("Get Started") -> `VerificationScreen` -> `pushReplacement(HomeShell(profile))`.
Sign out (Profile app bar, and the "sign out" link on Edit Employment Info) does `pushAndRemoveUntil(VerificationScreen)`, so it skips Welcome.

`HomeShell` tabs (IndexedStack): 0 Profile, 1 Alumni, 2 Jobs, 3 Chat, 4 News, 5 Market.
- Profile: Edit Employment Info (`ProfileSetupScreen`), Subscribe (`SubscribeScreen`), other people's `ProfileDetailScreen`.
- Alumni: `AlumniScreen` has two inner tabs, Directory and Nearby (`NearbyAlumniScreen`). Nearby opens `CityGroupChatScreen` (from a city card and from a bottom sheet, `nearby_alumni_screen.dart:382,418`). Directory opens `ProfileDetailScreen`.
- Jobs: `JobBoardScreen` -> `JobDetailScreen` -> `ApplyJobScreen`, `PostJobScreen`, `JobApplicantsScreen`, `NotificationsScreen` (bell), `EmailLogScreen`, Subscribe.
- Chat: `MessagesListScreen` -> `ChatScreen`.
- News: `AnnouncementsScreen` (no detail screen exists; cards show the full body inline).
- Market: `MarketplaceScreen` -> `MarketplaceDetailScreen`, `MarketplaceFormScreen`, `MyListingsScreen`, `MarketplaceAdminScreen` (admin only), report sheet, Subscribe gate (`marketplace_gate.dart`).

### Tests that depend on HomeShell, tab indexes or WelcomeScreen
None. `grep` finds no test referencing `HomeShell`, `WelcomeScreen`, `NavigationBar` or tab indexes. Existing tests use `MarketplaceScreen` and friends directly with `FakeApi` (`test/support/fake_marketplace_api.dart`). No existing test can break from the hub change; new tests must be written for the shell.

### Data the "Latest" strip can reuse (no new queries)
- Newest jobs: `job_board_screen.dart` runs `from('job_posts').select('*, poster:alumni_profiles(name)').order('created_at', desc)` directly on the Supabase client (private `_fetchJobs`, not in a repository). The strip needs the same read, limited to 3. I will add a small home data class with a fetch seam (so tests can fake it) that runs this same query shape with `.limit(3)`. This is the same table and columns, not a new query pattern.
- Newest approved listings: `MarketplaceRepository.fetchApproved()` already returns approved listings newest first. The strip takes the first 3. No new query.
- Announcements: `from('announcements').select().order('created_at', desc)`; the carousel will use the same read with `.limit(5)`.

### Persistence of a verified profile id (for Stage 3)
- Android/iOS: `flutter_secure_storage` (Keystore / Keychain) holds the PIN hash and the small "remembered profile" record. `local_auth` for biometrics.
- Web: no real secure storage (`flutter_secure_storage` on web uses WebCrypto with a key kept next to the data in localStorage, which is not real protection) and `local_auth` has no web support. Recommendation: no lock on web (see Decisions log).
- Smallest package set: `flutter_secure_storage`, `local_auth`, and `crypto` (PBKDF2-HMAC-SHA256; `crypto` is already in `pubspec.lock` as a transitive dependency, so it only becomes a direct dependency). `shared_preferences` is not needed: every value we store is small and goes in secure storage. Not added yet.

### Conflicts and risks noticed
1. There is no real auth. A remembered profile id is only a convenience; see the honesty rule in Stage 3.
2. `ProfileDetailScreen` and `ProfileSetupScreen` sign-out both push `VerificationScreen` directly. Stage 3 must route them through one "sign out" path that also clears local unlock data.
3. `AnnouncementsScreen` has `automaticallyImplyLeading: false` (built as a tab root). When reached from the Home hub it is a pushed route, so it needs a back button (a small change: a `showBack` flag).
4. `JobBoardScreen`, `AlumniScreen` (with its two inner tabs), `MarketplaceScreen` and `AnnouncementsScreen` all set `automaticallyImplyLeading: false`. Pushed from the Home tiles they would have no back arrow. Plan: wrap them in a small pushed-page host that provides a back arrow, without editing those screens more than needed.
5. Marketplace admin check `isAdmin` runs on every `MarketplaceScreen` mount. Fine.
6. `PROJECT_NOTES.md` has no entry for marketplace stages 1 to 5; backfilled in the Stage 1 commit (see Decisions log D-2).
7. The seeds make `farrel.abi.saleh@gmail.com` (a real-looking personal email) the demo admin in a public repo. Recorded here, audited in Stage 5.

### Stage plan adjustments
None needed. Everything in Stages 1 to 5 is possible on this repo.

---

## Stage 1: Home hub

**Status: DONE**

### What changed
- New: `lib/screens/home_screen.dart` (greeting, banners, tiles, Latest strip), `lib/screens/home_pages.dart` (builders for every page the shell/hub opens; defaults are the real screens, tests pass fakes), `lib/data/home_repository.dart` (`HomeApi` seam: latest announcements and jobs), `lib/widgets/banner_carousel.dart` (carousel + welcome card), `lib/widgets/announcement_card.dart` (extracted from the News screen), `lib/screens/announcement_detail_screen.dart`.
- Changed: `home_shell.dart` (4 tabs: Home, Directory, Chat, Profile), `announcements_screen.dart`, `alumni_screen.dart`, `job_board_screen.dart`, `marketplace_screen.dart` (each got a `showBack` flag, default false, so pushed-from-Home copies get a back arrow and tab roots look exactly as before; `AlumniScreen` also got `initialTab`).
- Tests: `test/home_screen_test.dart`, `test/home_shell_test.dart`, `test/support/fake_home.dart` (30 new tests).

### Behaviour
- Greeting uses the first word of `name`.
- Banners: latest 5 announcements as text cards (title, 2-line excerpt, date). Auto-advance every 5 s (pauses while a finger is down), swipe, dots, tap opens the full announcement. 0 announcements: a static "Welcome to Lingkaran" card. Loading spinner and an error card with "Try again" (no raw error text shown). "See all announcements" is always visible and opens the News screen.
- Tiles: Jobs, Marketplace, Nearby Alumni are pushed screens; Directory switches to the Directory bottom tab (see D-3).
- Latest: 3 newest jobs (same `job_posts` query shape as the Job Board, `limit 3`) and 3 newest approved listings (`MarketplaceRepository.fetchApproved`, sorted newest first, first 3). Each opens the existing detail screen. Empty and error states are separate per strip. No fee or commission wording.
- Back: from Directory, Chat or Profile back returns to Home; from Home it leaves the shell (same rule as before, first tab is now Home).
- Kept: shared `_currentUser` notifier (test proves every page gets the same instance); epoch refetch for Chat (test), and for Home. Jobs and Marketplace are built fresh on every open, so they refetch every time.

### Regression guard (reachability)
Test group "reachability" in `test/home_shell_test.dart` plus the checklist below.

| Screen | How to reach it now | Covered by |
|---|---|---|
| Profile (+ Edit info, Subscribe, sign out) | Bottom nav: Profile | test (nav), unchanged code |
| Alumni Directory | Bottom nav: Directory, or Home tile Directory | test |
| Nearby Alumni | Directory tab inner "Nearby" tab, or Home tile Nearby Alumni | test (tile), default-wiring test |
| City chat | From Nearby (unchanged code in `nearby_alumni_screen.dart`) | unchanged, no widget test (needs Supabase) |
| Jobs (+ detail, apply, post, applicants, notifications, email log) | Home tile Jobs, or a job in the Latest strip | test (tile), default-wiring test |
| Chat | Bottom nav: Chat | test |
| News | Home "See all announcements", or a banner | test |
| Market (+ detail, form) | Home tile Marketplace, or a listing in the Latest strip | test |
| My listings, Admin queue | From the Marketplace screen (unchanged) | existing marketplace tests |

Nothing became unreachable. Unchanged sub-flows (city chat, my listings, admin queue, job apply) are reached from screens whose code I did not change except for the back-arrow flag, and I did not test city chat with a widget test because it needs a live Supabase client.

### Checks run
- `flutter analyze`: no issues.
- `flutter test`: 110 tests, all pass (80 before, 30 new).
- `flutter build web --release`: succeeds.
- Bugs the tests caught while building: `setState(() => _x = future)` returned a Future in three retry handlers (Flutter asserts). Fixed by using block bodies.

### Could not test
- Real network data (no Supabase project, by rule). The Supabase queries are the same shape as the ones the Job Board and News screens already use; `.limit()` is the only addition.
- Auto-advance timing on a real device; tested with fake time only.
- Dark theme: the app has only a light theme (`AppTheme.light()`).

### Assumptions
- Item price in the marketplace strip row is shown (it is the item's price, not a fee); see D-5.

### Surprises and risks
- The News and Jobs screens hard-coded "no back arrow" (built as tab roots). I added `showBack` rather than wrapping them, to avoid double app bars.
- The Home tab now sits before Profile, so a returning user lands on Home instead of Profile. This is what the prompt asked for.

---

## Stage 2: Upcoming Preview tiles

**Status: DONE**

### What changed
- New `lib/widgets/upcoming_section.dart` (section, tiles, badge, info sheet); added below the Latest strip in `home_screen.dart`.
- `home_screen.dart`: swapped the lazy `ListView` for a `SingleChildScrollView` + `Column`, because the sections are a short fixed set and the lazy list did not build off-screen sections (found by the new tests).
- Tests: `test/upcoming_preview_test.dart` (4 tests).

### Behaviour
- Three muted tiles: Events, Mentoring, Business directory. Each has a "Preview" badge.
- Tap opens a bottom sheet: name, one-line description, badge, "This feature is a preview and is not available yet.", and a Close button. No route is pushed.
- No dates, no promises, no money features (no donations, crowdfunding, merchandise, scholarship), no new tables, no tap tracking.

### Checks run
- `flutter analyze`: no issues. `flutter test`: 114 pass (4 new). `flutter build web --release`: succeeds.
- Tests cover: badge on each tile, sheet opens with the right name and notice, nothing navigates, banned words absent from the section text, no overflow at 320 px.

### Could not test
- Look and feel of "muted" on a real screen (checked by code only: reduced-alpha surface and grey text).

### Optional idea (NOT built): "notify me" interest counter
Would need a table like `feature_interest(feature, profile_id, created_at)` and a write path. Because there is no real auth, anyone could inflate counts by spamming with fake profile ids, so the numbers would be unreliable. It also touches the "no tracking" rule. If you want a demand signal, a cheaper way is asking in the WhatsApp group. Not built, as instructed.

---

## Stage 3: Returning-user lock screen

**Status: DONE** (verified by tests with fakes and by the web build; NOT run on a real Android or iOS device, see "Could not test")

### Honesty rule (also in README)
Verification is still an email match with no real auth. Anyone who knows a valid alumni email can still verify as that person, on any device. This lock is a **device-level convenience lock, not real security**. It does not protect data in the database. The README and the PIN setup screen both say so.

### What changed
- New `lib/lock/`: `lock_config.dart` (all numbers), `pin_hasher.dart`, `masking.dart`, `lock_store.dart` (secure storage seam), `biometrics.dart` (provider seam), `lock_service.dart`, `pin_pad.dart`, `lock_screen.dart`, `pin_setup_screen.dart`, `app_entry.dart` (first screen), `lock_overlay.dart` (relock after background), `session.dart` (enter app, sign out).
- Changed: `main.dart` (home is `AppEntry`, `LockOverlay` wraps the app), `welcome_screen.dart` (optional `notice`), `verification_screen.dart` (remember, offer PIN; DB match moved to an injectable `verifyEmail`, same logic), `profile_detail_screen.dart` and `profile_setup_screen.dart` (sign out now clears local data first, then goes to Verification as before).
- Platform files: Android `MainActivity` now extends `FlutterFragmentActivity`, `USE_BIOMETRIC` permission, `LaunchTheme` parent is an AppCompat theme (needed by `local_auth`); iOS `NSFaceIDUsageDescription`.
- README: new section (behaviour, honesty rule, web decision, known gaps).
- Tests: `test/lock/*` and `test/support/fake_lock.dart` (63 new tests).

### Behaviour
- After a successful verification the device stores: profile id, display name, masked email (`a***@example.com`). Nothing else. No full email, no full profile, no OTP (there is none).
- Then a PIN setup screen (enter twice; easy PINs like 111111 or 123456 are refused). If the device has biometrics, a second step offers to turn them on; turning on needs one successful biometric check. "Skip for now" is always there.
- App start: remembered person -> lock screen (dark indigo, kawung mark, initials avatar, "Welcome back, <first name>", masked email, 6-digit pad, fingerprint key if enabled, "Forgot PIN? Verify again", "Not you? Switch account"). No remembered person -> Welcome, as before.
- Correct PIN or biometric -> fetch profile by id -> HomeShell. Profile missing, not verified, or fetch fails -> clear local data, Welcome with a short message (no raw error).
- Wrong PINs: remaining attempts shown; from the 3rd wrong try a 10 second wait (pad disabled, countdown, attempts in the wait are not counted); 5th wrong PIN wipes local data and returns to Welcome with a message. Counters are stored, so restarting the app does not reset them.
- Biometrics: optional, prompts on show and via the key; failure, cancel or unavailable shows "Use your PIN instead." and the PIN pad works; biometric failures do not use up PIN attempts.
- Relock: after more than `kLockAfterBackground` (5 minutes, one named constant) in the background, a lock screen covers the app (the app stays alive underneath, hidden). Only when a person is signed in and a PIN exists.
- Skipped PIN: next launch shows the lock screen with a "Continue" button that goes to Verification.
- "Forgot PIN", "Not you? Switch account" and Profile > Sign out clear local data only. Nothing is sent to the server.
- Web: no lock at all (see D-14).

### Packages added (rule 5)
| Package | Version | Why |
|---|---|---|
| `flutter_secure_storage` | ^11.2.0 | PIN hash and remembered-person record in Keychain / Keystore-backed storage |
| `local_auth` | ^3.0.2 | Optional fingerprint / face |
| `crypto` | ^3.0.7 | HMAC-SHA256 for PBKDF2. Already in `pubspec.lock` as a transitive dependency; now a direct one |
`intl` also appeared in the lock file as a transitive dependency of `local_auth`. `shared_preferences` was not needed. No other package added.

### PIN hashing
PBKDF2-HMAC-SHA256, 16-byte random salt (`Random.secure`), 60,000 iterations (measured about 0.44 s on this machine in JIT; run in a background isolate on device via `compute`), constant-time compare. The stored string carries its own iteration count. Checked against RFC 6070-style published vectors (1, 2 and 4096 iterations). Limit: a 6-digit PIN has 1,000,000 values, so an attacker who can read the secure storage of a rooted device can still brute-force it offline. The 5-attempt wipe only limits guessing through the app.

### Checks run
- `flutter analyze`: no issues. `flutter test`: 173 pass (63 new). `flutter build web --release`: succeeds.
- Covered: PBKDF2 vectors; hash correct/wrong/malformed; salt differs; masking never reveals the full address; remembered store holds only 3 values and no full email; PIN store never contains the PIN; lockout at 5 (data wiped), delay after 3rd, wait not counted, counter survives restart, reset on new PIN; remembered person shows lock screen while new user shows Welcome; web (disabled) shows Welcome; unreadable storage behaves like a new user; unlock enters the app; missing/unverified/failed profile clears data and shows Welcome + notice; biometric success / failure / cancel / retry / not available; switch account and forgot PIN clear data; skipped PIN shows Continue; setup (match, mismatch, weak PIN, skip, biometric on/off); post-verification flow; background timeout with a fake clock (4 min no lock, 6 min lock, no PIN, not signed in, web, switch account on relock).
- Bug found by a test: `AppEntry` did not pass the injected clock to the lock screen, so the delay countdown used real time. Fixed.

### Could not test
- Anything on a real Android or iOS device: Keystore/Keychain behaviour, the real biometric prompt, the Android theme and activity changes, the Face ID string. No Android SDK or iOS toolchain here, so `flutter build apk` and `ios` were not run. The plugin setup follows the plugin READMEs.
- Real Supabase profile fetch (default fetcher is the same query the marketplace repository already uses: `alumni_profiles` by id).
- Whether the OS delivers `paused` then `resumed` in the way the relock logic expects on every device (tested with simulated lifecycle events only).

### Surprises and risks
- With no real auth, "remember this person" is a weak idea by itself: the remembered id is just a profile id. Anyone who can type the right email gets in without a PIN. Said in README and the setup screen.
- The seed makes a real-looking personal email the demo admin (see Stage 5).
- The verification screen still shows raw exception text on error (`e.toString()`); left as is here, audited in Stage 5.

---

## Stage 4: Polish and regression

**Status: DONE**

### Fee, commission and price wording search
- Searched `lib/` (case-insensitive) for `commission`, `fee(s)`, `biaya`, `service charge`, `platform fee`, `admin fee`, `transaction fee`, `charge`, `payment`, `price`, `Rp`.
- **No fee, commission or service-charge wording exists anywhere in `lib/`.**
- What does appear, all expected: listing prices (`formatRupiah`, "Price (whole rupiah)", "Price: low to high") in marketplace screens and the Home Latest row; the Subscribe screen's "Rp 99.000/year", "Annual plan only. One payment covers a full year." and "Demo only, no real payment is processed." (your 30 Sep decision, unchanged).
- Worth a second look: "One payment covers a full year" on the Subscribe screen sits next to a demo that takes no payment; the "Demo only" line right below it covers this, but you may want it softer.
- New guard: `test/no_fee_wording_test.dart` fails if fee or commission wording is added to `lib/`.

### Layout and theme
- The app has only a light theme (`AppTheme.light()`, no dark theme exists), so there is nothing to check in dark mode.
- New layout tests (`test/lock/lock_layout_test.dart`) at 320x568, 360x640 and 390x844 with 1.4x text: lock screen (with fingerprint key, during a wrong-PIN wait, without a PIN), PIN setup with an error, Welcome with a notice, and a very long name and email. Home and the Upcoming section were checked in Stages 1 and 2 at 320, 360 and 390 px.
- Fixed while doing this: on very short phones (under 640 px tall) the lock screen now hides the big mark and shrinks the avatar so the PIN pad is not pushed below the fold.

### Regression
- Existing 80 tests still pass. The Stage 1 reachability table still holds (`test/home_shell_test.dart`).
- Added `test/lock/sign_out_test.dart` (sign out clears local data and tears down the stack).
- Docs updated for the new navigation: README ("Market tab" wording, click-test link), `DEMO_SCRIPT.md` (bottom nav description, and a note that it no longer matches the pitch deck), `MARKETPLACE_CHECKLIST.md` (Market tab wording).
- `README.md` has the new section (home hub, Preview tiles, lock screen, honesty rule, known gaps), written in Stage 3.
- `PROJECT_NOTES.md` has an entry for the marketplace backfill and for Stages 0, 1, 2, 3 and 4.
- Manual click-test checklist: `docs/hub/CLICK_TEST_CHECKLIST.md` (also repeated in the final summary).

### Checks run
- `flutter analyze`: no issues. `flutter test`: 191 pass. `flutter build web --release`: succeeds.

### Could not test
- Real device behaviour (see Stage 3), real Supabase data, dark mode (none exists).

### Surprises
- `DEMO_SCRIPT.md` said the bottom nav mirrors the pitch deck; it no longer does (deck: Alumni, Jobs, Chat, News). Flagged for you.

---

## Stage 5A: Security audit (report only)

**Status: DONE**

### What changed
- New `SECURITY_AUDIT.md` (verdict, 25 findings, A01 to A10 walk-through with the table and function access matrices, personal-data inventory, what I could not check, fix order).
- New proof tests, kept apart from app code: `supabase/tests/security_audit/{probes.sql,run_audit.sh}` (38 probes on a throwaway local Postgres, synthetic `example.com` fixtures only, no seed files loaded, so no real person's data is used) and `test/security_audit/proof_weaknesses_test.dart` (4 tests). No application code was changed in Part A.

### Result in one line
Not safe to load real data. 5 Critical, 6 High, 9 Medium, 5 Low. The Critical and most High items need real Supabase Auth.

### Checks run
- `bash supabase/tests/security_audit/run_audit.sh pre`: all 32 weakness probes show the weakness, all 6 controls stay blocked (so the harness can tell the difference).
- `bash supabase/tests/run_local.sh`: passes (existing marketplace SQL checks).
- `flutter analyze` clean, `flutter test` all pass (proof tests included).
- pub.dev advisory list checked for all 121 locked packages: `http` and `shared_preferences_android` have advisories, both fixed below the locked versions.

### Could not test
See section 6 of `SECURITY_AUDIT.md` (live project, deployed site, the real deployed key, other branches' history, real devices, PostgREST).

### Assumptions
- The live database matches the migrations in the repo. It may not (Session 30 changed policies by hand).
- Whether the seed's admin exists on the deployed database is unknown.

### Surprises
- The admin's email is a real-looking personal address in a public repo and it is the demo admin. Combined with SA-03, anyone can open the admin queue by typing it into Verification.
- Three real-looking people (names and emails) are in `seed.sql`, a fourth email is in `PROJECT_NOTES.md`.

---

## Stage 5B-1: Web hardening (SA-12, SA-19)

**Status: DONE**
- `vercel.json`: catch-all `headers` rule with `Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (camera, microphone, geolocation, payment, usb off), `Strict-Transport-Security`.
- `scripts/check_supabase_env.sh` (new) and `scripts/vercel-build.sh`: the build refuses unless `SUPABASE_URL` is https and the key is `sb_publishable_...` or a JWT with role `anon`. `service_role`, `sb_secret_...`, unknown or malformed keys stop the build with a message that never prints the key.
- Tests: `test/security_fixes/web_hardening_test.dart` (11 tests). Written first and run before the fix: the header tests and the accept tests failed (no headers, no script); they pass now. The proof tests for SA-12 and SA-19 were removed from `test/security_audit/` because the fix replaces them.
- Real browser check: served a local release build with the exact headers from `vercel.json` in Chromium. The Welcome screen renders and there were no CSP violations. The only failures were the Google Fonts downloads, which fail the same way with no headers because this sandbox cannot validate Google's certificate.
- Not tested: the CDN path (CanvasKit from `www.gstatic.com`, which is what Vercel's build uses): the sandbox cannot reach it. It is allowed in `script-src` and `connect-src`; test the deployed preview before promoting. If the Supabase project ever moves to a custom domain, `connect-src` must be updated.

---

## Stage 5B-2: Input safety in the app (SA-13, SA-14)

**Status: DONE**
- New `lib/util/friendly_error.dart` (safe messages; the exception text is never shown), `lib/util/safe_url.dart` (`parseHttpUrl`, `validateHttpUrl`, `openHttpUrl`: only http and https, real host, no embedded credentials, max 500 chars, bare `linkedin.com/in/x` becomes https), `lib/widgets/safe_link_chip.dart`.
- Replaced raw error text on 16 screens (verification, apply, post job, subscribe, both chats, open-conversation, and eight "Failed to load ..." screens).
- Job applicant links (LinkedIn, portfolio, CV) open through `SafeLinkChip`; an unsafe link shows "This link isn't valid or can't be opened." and opens nothing. The apply form now validates the two link fields and stores the normalised URL. The marketplace shop link uses the same parser (the database already required http/https; this is defence in depth).
- Tests: `test/security_fixes/input_safety_test.dart` (22 tests). Run before the screen changes: the verification screen test, the "no raw error in any screen" source scan, the "no raw `launchUrl(Uri.parse(...))`" scan and the apply-form test failed; they pass now. The Stage 5A Dart proof tests for SA-13 and SA-14 were removed (the weakness they proved is gone).
- Checks: analyze clean, 219 tests pass, web build ok.

---

## Decisions log
- **D-1 (branch base).** `feature/home-hub` is created from `claude/beautiful-cori-mntun6`, as instructed. The other named branches are not in this clone, so I could not compare against them.
- **D-2 (PROJECT_NOTES backfill placement).** Stage 0 says "commit only the report file". Rule 10 says backfill the marketplace entry first. I kept Stage 0 to the report file only and put the marketplace backfill entry, the Stage 0 entry and the Stage 1 entry into the Stage 1 commit.
- **D-3 (Bottom nav set and where Nearby lives).** I built the proposed 4 items: Home, Directory, Chat, Profile. The "Directory" tab still shows the existing `AlumniScreen` (Directory and Nearby inner tabs), so Nearby stays reachable there as well as from the Home tile. The Home Directory tile switches the tab instead of pushing a second copy. Rejected: a 5th "Jobs" tab (the prompt wanted a slimmer nav); a separate Nearby-only screen (would duplicate the existing one).
- **D-4 (Showing back arrows).** Rejected wrapping screens in a new host scaffold (double app bar). Chose a `showBack` flag (default false) on Jobs, Marketplace, Announcements and Alumni; defaults keep old tab-root behaviour.
- **D-5 (Price in the Latest strip).** The strip row shows category, city and the item price. The prompt says the strip shows "no fees or fee wording"; I read that as the platform fee or commission, not the item price. Tell me if you want the price removed.
- **D-6 (Testing seam).** `HomePages` (builders) and `HomeApi` are injected so the shell and hub can be tested without Supabase. The alternative (initialising a fake Supabase client in tests) is heavier and slower.
- **D-7 (Grid shape).** 2x2 tiles with icon and label side by side, not 4 across, so "Marketplace" and "Nearby Alumni" never overflow at 320 px wide.
- **D-8 (Epoch keys).** Kept for Chat and Home. Jobs and Market no longer need them because they are pushed fresh each time.
- **D-9 (Auto-advance).** 5 seconds, paused while a finger is down.
- **D-10 (Local Flutter SDK).** Installed Flutter 3.47.5 outside the repo (`/opt/fl`) so checks are real. Created a local `.env` from `.env.example` (placeholders only, gitignored) because tests and analyze need the asset to exist.
- **D-11 (Preview copy).** Descriptions: Events "Sports, reunions and sharing sessions with fellow alumni."; Mentoring "Connect with alumni for career guidance."; Business directory "Find businesses run by alumni." One sentence each, no dates or promises. Rejected: "Coming soon" wording (it is a promise).
- **D-12 (Tile layout).** A vertical list of three rows, not a 3-across grid, so names never overflow at 320 px.
- **D-13 (Home scroll view).** Replaced `ListView` with `SingleChildScrollView` + `Column` (all sections built, pull-to-refresh still works).
- **D-14 (Web: no lock).** On web, nothing is remembered and no lock is shown; every visit starts at Welcome. Why: browsers have no real secure storage (the plugin's web mode keeps its key next to the data in localStorage) and this setup has no biometrics on web. A remembered profile id plus a PIN hash in localStorage would look like protection but let anyone with the browser profile skip verification and guess a 1,000,000-value PIN offline in moments. Rejected: PIN-only on web (false sense of security, same reason); remembering the profile without a PIN on web (removes the only thing the lock does).
- **D-15 (What is stored).** Profile id, display name, masked email, PIN hash, wrong-try counter, wait-until time, biometric flag, all in secure storage under `lingkaran.lock.v1.*`. The masked email is computed before storing, so the full address never touches the device store. `shared_preferences` not used.
- **D-16 (Delay length).** 10 seconds from the 3rd wrong try on (the 3rd and 4th). One constant, `kWrongPinDelay`.
- **D-17 (PBKDF2 cost).** 60,000 iterations in pure Dart on a background isolate. Higher would slow unlock on cheap phones; it cannot make a 6-digit PIN strong anyway. Stored with the hash so it can be raised later.
- **D-18 (Forgot PIN / Switch account destination).** Both go to Welcome ("normal first-time flow"). In-app Sign out keeps its old destination (Verification) but now also clears the local data.
- **D-19 (No-PIN variant).** A remembered person without a PIN sees the lock screen with "Continue" (to Verification) and no pad, as specified. Relock-after-background is skipped when there is no PIN.
- **D-20 (Relock design).** An overlay above the Navigator (`MaterialApp.builder`) hides the app with `Offstage` instead of pushing a route, so open screens and scroll positions survive. Rejected: pushing a lock route (breaks back stack and dialogs).
- **D-21 (Biometrics scope).** `biometricOnly: true`, so the phone's own PIN or pattern is not accepted; our PIN is the only fallback. Biometrics can only be turned on after a PIN exists.
- **D-22 (Weak PIN list).** Refuse all-same-digit PINs and 123456, 654321, 012345, 123123. A device lock, not a password policy.
- **D-23 (Failed profile fetch clears data).** As the prompt says, a failed fetch (including a plain network error) clears local data and shows Welcome. This is harsh on a flaky connection; the alternative (retry, keep data) contradicts the prompt. Flagged for your review.
- **D-24 (Testing seams).** `LockStore`, `BiometricProvider`, clock, `ProfileFetcher`, `EmailVerifier` and `HomeBuilder` are injected so tests run without plugins or Supabase.
- **D-25 (Audit fixtures).** The audit does not load `seed.sql` or `seed_marketplace.sql`, so the local database holds only synthetic `example.com` people. Rejected: reusing the seed admin (a real person's address) for the admin-takeover proof.
- **D-26 (Proof test style).** Proof tests assert the weakness is present (they pass today) and are flipped in Part B, so the same check fails before a fix and passes after. Rejected: tests that fail today (would break every CI run for findings that cannot be fixed without auth).
- **D-27 (Real emails in the report).** The report masks real-looking addresses (`f***@gmail.com`) and gives file and line instead of the value.
- **D-28 (pub.dev lookup).** I queried pub.dev's public advisory endpoint for the locked packages. It is a public read-only list, not a probe of a system under test, but it is an outside call, so it is logged here.
- **D-29 (CSP shape).** `style-src` keeps `'unsafe-inline'` because Flutter web injects inline styles; scripts have no `'unsafe-inline'` and no `'unsafe-eval'` (only `'wasm-unsafe-eval'` for CanvasKit). `img-src` allows any `https:` because marketplace photos can come from any host (seed uses an image service). Rejected: a hash-based or nonce CSP (Flutter's bootstrap is generated at build time; higher risk of breaking the deploy).
- **D-30 (Key check accepts both key formats).** New `sb_publishable_` keys and legacy anon JWTs are both accepted; anything else fails the build.
- **D-31 (Bare links).** A link typed without a scheme (`linkedin.com/in/x`) is accepted and stored as `https://...`. Rejected: refusing it (LinkedIn users usually paste it that way). A value with any scheme other than http or https is refused.
- **D-32 (Error text).** All user-visible errors are generic or network-only messages. Nothing logs the original error anywhere the user can see. Rejected: keeping the detail behind a "show details" toggle (still leaks through screenshots and support requests).
