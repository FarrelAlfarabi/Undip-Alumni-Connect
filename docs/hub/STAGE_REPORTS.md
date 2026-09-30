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
