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
