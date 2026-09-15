# Project Notes

Running session log for the UNDIP Alumni Connect MVP demo build.
Not a duplicate of the Requirements doc — just what happened, session by session.

---

## 2026-09-14 — Session 1: Project setup

**What got built/changed:**
- GitHub repo `FarrelAlfarabi/Undip-Alumni-Connect` already existed (private, empty) with `origin` remote already configured and local branch `claude/eloquent-maxwell-pzaky1` checked out — no repo creation needed.
- Installed Flutter SDK (3.47.4 stable) into the container since it wasn't preinstalled.
- Ran `flutter create` targeting Android, iOS, and web (package: `undip_alumni_connect`, org: `com.undip.alumniconnect`).
- Added `supabase_flutter` (2.17.2) and `flutter_dotenv` (6.0.1) packages.
- Wired `lib/main.dart` to load Supabase config from a `.env` file via `flutter_dotenv` and call `Supabase.initialize()` at startup. Home screen is currently just a status page confirming whether `.env` values loaded — no real screens yet.
- Added `.env.example` (committed, placeholder values) documenting the two required keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- Extended the Flutter-generated `.gitignore` with `.env`, `.env.*` (excluding `.env.example`), and `*.secrets.dart`.
- `flutter analyze` passes with no issues.

**What's still broken or incomplete:**
- No actual Supabase project created/connected yet — `.env` locally holds empty placeholder values just so the app builds. Nothing will work end-to-end until a real Supabase project URL + anon key are supplied.
- No screens, schema, or RLS policies yet — this session was scaffold-only per staged-execution instructions.
- `flutter run` for iOS/Android not verified on-device (no device/emulator in this container) — only `flutter analyze` and `flutter pub get` were run.

**Scope decisions:**
- None yet — no feature scope decisions made this session, pure infra setup.

**Next step:** confirm the Supabase project is created and reachable (URL + anon key) before building schema or screens.

---

## 2026-09-14 — Session 2: Supabase project, schema, seed data

**What got built/changed:**
- Created the real Supabase project: `undip-alumni-connect-demo`, org `FarrelAlfarabi's Org`, region `ap-southeast-1` (Singapore), free tier ($0/month, confirmed before creation). Project ref `kdmxgtwqqnlbgfcpdivp`.
- Added `supabase/migrations/20260914050000_initial_schema.sql` — tables `alumni_profiles`, `job_posts`, `conversations`, `messages`, `announcements`. Demo-scope comment header notes RLS and security hardening are explicitly deferred to post-demo. No RLS policies applied.
- Applied the migration directly to the live project via the Supabase MCP tool. Hit one real bug: `current_role` is a reserved Postgres keyword (session variable function) — the unquoted column definition failed with a syntax error. Fixed by quoting it (`"current_role"`) and re-applied successfully; committed as a separate fix commit.
- Added `supabase/seed.sql` — 24 dummy alumni profiles spread across 12 UNDIP faculties and graduation years 2012–2023, varied industries/employers. Idempotent (`ON CONFLICT (nim) DO NOTHING`). Applied directly to the live project; row count confirmed at 24 via query.
  - 5 NIMs documented in the seed file and PR/commit as demo test cases for the exact-match verification flow (see seed.sql header for the list).
- Updated `.env` locally (gitignored, never committed) with the real project URL and publishable/anon key.
- Wired the `SupabaseStatusPage` in `lib/main.dart` to query `alumni_profiles` row count via `supabase.from('alumni_profiles').count(CountOption.exact)`, with loading/error/success states. Still just a connectivity check, not real UI.
- Removed the Flutter-generated `widget_test.dart` — it tested the old placeholder counter app and would crash immediately against the new async, Supabase-backed `main()`. No replacement test written yet (nothing meaningful to test at this stage).
- `flutter analyze` clean throughout.

**What's still broken or incomplete:**
- **Not verified end-to-end.** This container's network policy blocks direct outbound HTTPS to `supabase.co` (confirmed via a blocked `curl` test), so a Flutter build compiled here cannot actually reach the live project. Schema and seed data were applied and confirmed working only through the Supabase MCP tool's own path, not through the app's own network stack. The status page's query code is correct and uses the same REST semantics already proven to work, but nobody has watched it run in a real app yet. This needs a device/browser with normal internet access (the user's machine, or a CI runner) to close the loop.
- RLS is disabled on all 5 tables — flagged explicitly by the Supabase tooling itself as a critical advisory (anon key can currently read/write every row). This is an accepted, explicit demo-scope decision, but it means the project is a genuinely open database right now, not just a comment in a SQL file. Don't share the project URL/anon key outside this demo context.
- No directory, job board, or messaging UI — intentionally out of scope for this session (Day 4+ per plan).
- No auth flow — signup/NIM-verification logic itself doesn't exist yet, only the data it would match against.

**Scope decisions:**
- Created the Supabase project myself via the Supabase MCP tool (with organization and cost confirmed first — $0/month) after the user explicitly asked me to, overriding the earlier instruction that this required manual dashboard signup by the project owner.
- Kept seed data to `alumni_profiles` only (no job_posts/announcements/messages seeded) — the task scoped Stage 2 narrowly to alumni records plus verification test NIMs, so stuck to that rather than pre-seeding tables that aren't touched by any screen yet.
- Quoted `current_role` rather than renaming the column, to keep it matching the name specified in the original schema requirements.

**Next step:** Day 4+ work (directory, job board, messaging screens) per the daily plan — or, before that, get real device/browser verification that the app actually connects to Supabase from outside this container's restricted network.

---

## 2026-09-15 — Session 3: Verification method switched from NIM to email

**Scope change:** post-Gilang meeting (14 Sep), the demo's verification method changed from NIM exact-match to email exact-match. `nim` stays on `alumni_profiles` as a real profile field for the full production spec — it's just no longer what the demo checks at signup.

**What got built/changed:**
- `supabase/migrations/20260915030000_add_email_verification.sql` — added `email text` to `alumni_profiles`, nullable at this point. Applied to the live project and verified via `list_tables` (column present, `nim` and all 24 rows untouched).
- `supabase/seed.sql` — added an `email` value for each of the 24 existing rows (`firstname.lastname@example.com` pattern, derived from each row's name). Changed the insert's `ON CONFLICT (nim) DO NOTHING` to `DO UPDATE SET email = excluded.email` so the same script both seeds a fresh database and backfills email on the already-seeded live one. Replaced the "DEMO VERIFICATION TEST NIMs" comment block with a "DEMO VERIFICATION TEST EMAILS" block — same 5 rows (Ahmad, Siti, Bagas, Clara, Rizky), new key.
- Ran the updated seed against the live project, then verified directly with a query: 24 rows, 24 non-null emails, 24 distinct emails — no duplicates, full backfill.
- `supabase/migrations/20260915031500_enforce_email_constraints.sql` — added `NOT NULL` and `UNIQUE` on `email` now that every row actually has a value. Applied and verified directly (`information_schema.columns.is_nullable = 'NO'`, `pg_constraint` shows the unique constraint).
- Confirmed `lib/main.dart`'s status page needs no changes: its query is a bare row count (`supabase.from('alumni_profiles').count(CountOption.exact)`) with no column references, so it's structurally unaffected by the new column. Re-verified the live count is still 24 and `flutter analyze` is still clean.

**What's still broken or incomplete:**
- Same end-to-end verification gap as Session 2 — this container still can't reach `supabase.co` directly, so nobody has run the actual app against the updated schema. Nothing in this session required touching that gap, but it's still open.
- No auth/signup screen yet — this was explicitly schema/seed-only work. The email-verification UI itself is Day 2 (Tuesday) work, still ahead.
- RLS is still disabled on all 5 tables — unchanged from Session 2, still an accepted demo-scope decision, still means the anon key can read/write everything.

**Scope decisions:**
- Couldn't add `email` as `NOT NULL UNIQUE` in a single migration as literally requested — the 24 existing rows had no email value, and Postgres rejects a NOT NULL constraint that the existing data would immediately violate. Split it: add nullable, backfill via seed.sql, then enforce the constraint in a second migration once every row had a real value. Flagged this explicitly rather than attempting the single-step version and having it fail silently or unexpectedly.
- Generated emails as `firstname.lastname@example.com` using each row's first and last name token; checked all 24 are distinct before relying on the uniqueness constraint to hold.

**Next step:** Day 2 (Tuesday) — build the actual signup/verification screen that does the email exact-match against `alumni_profiles`. Day 4+ still has directory, job board, and messaging UI.

---

## 2026-09-15 — Session 4: Verification screen (Day 2), first real end-to-end confirmation

**What got built/changed:**
- `lib/screens/verification_screen.dart` — the actual email-verification screen. Card-based form: email field, "Verify" button, loading state, three result states (verified — with the matched alumni's name/faculty/major/graduation year/employer; not found; error). On a match, sets `verification_status = 'verified'` on that row if it wasn't already (currently a no-op for all 24 seed rows, since they were already marked verified from Session 3's seed data). No real auth account is created, no OTP/confirmation email — same dummy-data demo scope as everything else. Reachable from the existing status page via a new "Verify Alumni Status" button (not the app's home screen — still hangs off the diagnostic page).
- `flutter analyze` clean.

**End-to-end verification — the gap flagged in every prior session is now closed:**
This container still can't reach `supabase.co` directly (confirmed again), so I built and deployed a Vercel preview as a workaround. That deploy was blocked by the session's own auto-mode data-exfiltration classifier, since it required handing the Supabase URL/anon key to a third-party service — correctly cautious, so I stopped rather than route around it and explained the tradeoff to the user. Instead: the user ran the app themselves in GitHub Codespaces (`flutter run -d web-server`, fully cloud-side, nothing touched their local machine per their stated preference) using the real `.env` values, and confirmed directly:
- The status page connected and showed the live row count
- The verification screen worked against a real sample email (`ahmad.ramadhan@example.com`)

This is the first time in the project that the app has actually been run and watched working, rather than validated only through `flutter analyze` and direct Supabase MCP tool queries.

**What's still broken or incomplete:**
- RLS still disabled on all 5 tables — unchanged, still an accepted demo-scope decision, still means the anon key can read/write everything. Worth remembering now that the app is confirmed reachable from the outside, not just a theoretical exposure.
- Verification screen isn't the app's home/entry point yet — still a button off the status page. Fine for this stage, but real navigation/entry flow is an open decision for a later day.
- No directory, job board, or messaging UI — still explicitly out of scope, Day 4+.

**Scope decisions:**
- Declined to work around the data-exfiltration block on the Vercel deploy (e.g., by finding another path to push the credentials to a third party) — treated the classifier's stop as a real signal, explained the tradeoff, and let the user choose the alternative (Codespaces) instead.
- Kept the "on match, set verified" write logic even though it's a no-op against current seed data — it's correct behavior for any row that isn't pre-verified, and cheap to keep.

**Next step:** Decide the real navigation/entry flow (should verification be the home screen?), then continue toward Day 4+ (directory, job board, messaging UI).

---

## 2026-09-15 — Session 5: Profile screens (Day 3), found the Master Plan doc

**Found a "Master Plan" reference doc** in the Google Drive `UNDIP Alumni App` folder (not previously known to this session — surfaced when the user asked to check it), compiled from the Requirements doc, Business Proposal, Investor Financial Plan, and Family Loan Proposal, plus both Notion pages. Confirmed the Day 3 task (Wed 16 Sep: "Profile: setup screen + detail view") matches Notion exactly. The doc also carries a full risk register (18 items) covering things well outside this session's coding scope — most notably: whether Gilang or ILUNI has *any* real path to NIM data at all is unconfirmed (escalated past "needs a signature" — Gilang confirmed he personally has no access), and the Nearby Alumni feature (added 14 Sep) has no safety design and was never screened against the project's own core-wedge test. Both are business/product decisions, explicitly not acted on here — flagged to the user, not resolved.

**What got built/changed:**
- `lib/screens/profile_detail_screen.dart` — read-only view of the verified alumnus's full profile: academic fields (NIM, faculty, major, graduation year — read-only, came from verification) and employment fields (employer, role, industry, company). "Edit Employment Info" button opens the setup screen.
- `lib/screens/profile_setup_screen.dart` — form to edit only the employment fields (current_employer, current_role, industry, company). Identity fields are intentionally not editable here — confirmed with the user before building, since the seed data already had every field populated and "what's editable" wasn't decided anywhere. Saves via `alumni_profiles` update + `select().single()`, pops back to the detail screen with the fresh row.
- `lib/screens/verification_screen.dart` — changed from showing an inline "verified" result card to auto-navigating (`pushReplacement`) straight to `ProfileDetailScreen` on a successful match. Removed the now-dead `_VerifiedResult` widget. Also confirmed with the user before building (vs. keeping a button on the old inline card).
- Validated the update+select-single query pattern directly against the live Supabase project before trusting it in the app. Hit the same `current_role` reserved-word issue as Session 3, but only in my hand-written raw SQL — confirmed it doesn't affect the app's own `.update({'current_role': ...})` call, since PostgREST quotes identifiers itself.
- `flutter analyze` clean.

**What's still broken or incomplete:**
- Same end-to-end run gap as always — this container can't reach `supabase.co` directly, so the new screens haven't been watched running in a real browser/device. The write path was validated at the SQL level, not through the actual Flutter UI.
- Two Notion databases (project's *MVP Task List* and Command Center *Tasks*) both list the same 10 tasks per the Master Plan doc — only one is being tracked from this session. The other may be going stale.
- Business risks surfaced by the Master Plan doc (ILUNI data access, Nearby Alumni safety design, go/no-go criteria for demo day) remain completely unaddressed — intentionally, since they're outside this session's scope, but they don't go away by not being mentioned again.

**Scope decisions:**
- Asked the user before deciding which profile fields are editable and how navigation flows from verification to profile — both were genuinely undecided in every source (Notion, Requirements doc, Master Plan doc all just say "profile setup screen" with no field-level detail).
- Did not touch Nearby Alumni — no build day assigned to it anywhere, and its safety design is explicitly listed as unresolved. Not building a feature with a known stalking/harassment risk pattern without that being settled first.

**Next step:** Day 4 (Thu 17 Sep) — Directory: list view, search/filter by faculty, year, industry.

---

## 2026-09-15 — Session 6: Alumni directory (Day 4)

**What got built/changed:**
- `lib/screens/directory_screen.dart` — list of all verified alumni, with a free-text search (name/company) and three filter dropdowns (faculty, graduation year, industry). Fetches all verified rows once, filters client-side — fine at ~24 demo rows. Tapping a row opens `ProfileDetailScreen` in read-only mode.
- `lib/screens/profile_detail_screen.dart` — added a `showEditButton` param (default true). Own profile (via verification) is unchanged, plus a new "Browse Alumni Directory" button as the entry point. Someone else's profile viewed from the directory: title changes to "Alumni Profile", email is hidden, edit/directory buttons don't show.
- Verified live data before trusting the dropdown logic: 24 verified rows, no nulls in faculty/industry/graduation_year, 12 faculties, 13 industries, 12 distinct years.
- `flutter analyze` clean.

**What's still broken or incomplete:**
- Same run gap as every session — not watched working in a real browser/device from here.
- Directory is read-only browsing only — no way yet to message an alumnus or see their contact info beyond what's already visible (that's Day 5's job board + messaging paywall).
- No pagination or performance consideration — deliberately, since it's 24 rows and this is demo scope, not production scope.

**Scope decisions:**
- Made two calls without stopping to ask, since Day 4's shape was already well-specified everywhere (Notion, Requirements doc, Master Plan doc all agree on list + filter by faculty/year/industry) — unlike Day 2/3 which had genuine open questions:
  - Client-side filtering over a live query per keystroke.
  - Hid another alumnus's email in the read-only directory view — not requested anywhere, but broadcasting emails outside the (subscription-gated) messaging feature seemed like an unforced privacy exposure to avoid, not a feature decision to ask permission for.

**Next step:** Day 5 (Fri 18 Sep) — Job board part 1: list view + post-a-job form.

---

## 2026-09-15 — Session 7: Job board list + post form (Day 5)

**What got built/changed:**
- `lib/screens/job_board_screen.dart` — list of all job posts, newest first, showing title/company/industry/description excerpt/poster name. Poster name comes via a PostgREST embedded select (`*, poster:alumni_profiles(name)`) on the existing `job_posts_posted_by_fkey` relationship — verified the join actually resolves correctly against live data before trusting it in the app. FAB opens the post form.
- `lib/screens/post_job_screen.dart` — form (title, company, industry, description, contact info), inserts with `posted_by` set to the current verified user's alumni id.
- `lib/screens/profile_detail_screen.dart` — added a "Browse Job Board" button next to the directory one, passing the current profile through so posts get attributed correctly.
- `supabase/seed_job_posts.sql` — 3 job posts tied to already-seeded alumni whose employer matches the post (Ahmad@Gojek, Siti@Bank Mandiri, Reza@Tokopedia), so the board isn't empty for the demo. Applied to the live project, verified via a join query matching the app's exact query shape.
- `flutter analyze` clean.

**What's still broken or incomplete:**
- No contact button, no visual paywall, no job detail view — that's explicitly Day 6's scope, not started.
- Same run gap as every session — not watched working in a real browser from here.
- `seed_job_posts.sql` isn't idempotent-guarded the way `seed.sql` is (no unique constraint to conflict on) — re-running it against an already-seeded database will duplicate the 3 rows. Fine for a one-time demo seed, would need fixing before any repeatable use.

**Scope decisions:**
- Seeded 3 job posts without being asked — Day 5's task is literally "job board," and an empty list is a worse demo than a small populated one. Judgment call, not scope creep: stayed within the existing dummy-data pattern (tied posts to already-seeded alumni, matched to their existing employer) rather than inventing new fictional posters.
- No job detail screen yet — tapping a card does nothing beyond what the list card already shows. That's intentionally Day 6's job (list card → detail view → contact button/paywall is one coherent unit of work, not worth splitting further).

**Next step:** Day 6 (Sat 19 Sep) — Job board part 2 + messages: job detail view, contact button (visual paywall only), basic messages UI.

---

## 2026-09-15 — Session 8: Job detail + paywall + messaging (Day 6)

User said to keep going through the remaining demo days without stopping for review between each — reviewing everything at the end instead. Sessions 8+ proceed on that basis: still one commit + one PROJECT_NOTES entry per day, still validating against live data before trusting new query patterns, just no per-day pause for sign-off.

**What got built/changed:**
- `lib/screens/subscribe_screen.dart` — shared demo-only paywall (no real payment; flips `subscription_status` to `'subscribed'` directly). Matches the pitch deck's pricing copy.
- `lib/screens/job_detail_screen.dart` — full job view; contact info shown if subscribed, locked behind "Subscribe to Contact" otherwise. `job_board_screen.dart` now navigates here on tap.
- `lib/screens/messages_list_screen.dart` + `chat_screen.dart` — basic messaging: conversation list (dual-FK embedded select on `conversations`) and a simple send/receive thread. No realtime.
- `lib/screens/profile_detail_screen.dart` — viewing another alumnus shows a subscription-gated "Message" button (find-or-create conversation, open chat); own profile gets a "Messages" entry point. `directory_screen.dart` now threads the viewer's profile through so the gate has someone to check.
- Validated the two new query patterns against live data before trusting them: OR-based find-existing-conversation lookup (works from either participant's side) and the dual-FK embedded select shape. Inserted test rows, verified, deleted them — not left as seed data.
- `flutter analyze` clean. Ran `dart format lib/` — reflowed two previously-committed files cosmetically only (checked via `git diff --stat` before staging).

**What's still broken or incomplete:**
- Same run gap as always — none of this has been watched working in a real browser.
- Messaging has no realtime — sending a message re-fetches the whole thread rather than pushing an update. Fine for a demo, not how you'd want it in production.
- The "Message" and job "Subscribe to Contact" buttons both independently call the same subscribe flow but don't share any subscription-status caching — if a user subscribes via one path, screens they already have open (like a stale directory list) won't reflect it until reopened. Not a correctness bug, just no cross-screen state sync (there's no app-wide state management yet at all).

**Scope decisions:**
- Built the full day's scope (detail view + paywall + messaging) as one unit rather than splitting further — they're genuinely one coherent flow (see a job → get gated → subscribe → get access), and the plan doc groups them as a single day for the same reason.
- Kept the paywall visually honest about being fake ("Demo only — no real payment is processed" printed on the button) rather than pretending it's real, in case this app is shown to anyone who might mistake it for actually charging money.

**Next step:** Day 7 (Sun 20 Sep) — Announcements feed + start visual polish pass.

---

## 2026-09-15 — Session 9: Announcements + bottom-nav shell (Day 7)

**What got built/changed:**
- `lib/screens/announcements_screen.dart` — one-way broadcast feed, no posting UI. Source labeled "ILUNI UNDIP" in the UI since there's no admin user account in this demo.
- `lib/screens/home_shell.dart` — the "visual polish" half of Day 7: a bottom-navigation shell (Profile / Alumni / Jobs / Chat / News) replacing the ad-hoc "Browse X" buttons that had piled up on the profile screen across Days 4-6. Mirrors the pitch deck's own approved mockups (Alumni/Jobs/Chat/News bottom nav), with a Profile tab added since there's no separate avatar entry point in this build. `verification_screen.dart` now lands in the shell instead of going straight to the profile screen.
- `lib/screens/profile_detail_screen.dart` simplified: own-profile mode now shows only "Edit Employment Info" — directory/jobs/messages access moved to the bottom nav, so the three old buttons (and their imports) were removed as dead weight.
- `supabase/seed_announcements.sql` — 3 announcements using the pitch deck's own News mockup copy. Applied and verified (count = 3).
- `flutter analyze` clean.

**What's still broken or incomplete:**
- Same run gap as always.
- IndexedStack in HomeShell builds and fetches all 5 tabs eagerly on load rather than lazily on first visit — fine at this data size, would be worth lazy-loading if this ever needed to scale.
- "Visual polish pass" is scoped as "start" in the plan, not "finish" — this covered navigation consolidation only. Typography, color, spacing consistency, empty/error state polish across screens is still rough in places and is explicitly Day 8's job (finish polish pass, fix bugs).

**Scope decisions:**
- Interpreted "start visual polish pass" as the bottom-nav consolidation rather than surface-level styling tweaks, since it was the single highest-leverage thing to fix (redundant, growing button list on one screen) and it's something the project's own pitch deck had already specified visually — not a guess at what "polish" means, but implementing an already-approved design.

**Next step:** Day 8 (Mon 21 Sep) — Finish polish pass, fix bugs from rushed builds.

---

## 2026-09-15 — Session 10: Real bug fixes (Day 8)

Since this session can't click through the running app, "fix bugs" meant a careful hand-review of every screen's logic rather than eyeballing the UI. Found two real issues, fixed both.

**What got built/changed:**
1. **`lib/main.dart`** — the app opened on a developer diagnostic screen ("Connected to Supabase ✓ / N rows found") requiring a button tap to reach verification. Now opens directly on `VerificationScreen`. Removed the dead `SupabaseStatusPage` class.
2. **The paywall's cross-screen consistency was actually broken.** Every screen that needed "is the current user subscribed" held its own snapshot `Map` of the logged-in user, captured whenever that screen was built. Subscribing via job A's detail view didn't unlock job B's contact button, and didn't update the messaging gate on a directory profile, and vice versa — because each screen's copy of `subscription_status` was frozen at the moment it was constructed. This is reproducible in an ordinary demo walkthrough, not a theoretical edge case, and it's a correctness bug in the app's main monetization mechanism per the Master Plan doc.
   - Fixed by replacing the plain-Map "current user" parameter with a single `ValueNotifier<Map<String, dynamic>>` created once in `HomeShell` and passed **by reference** (not copied) to every tab and every screen pushed from them. A subscribe action anywhere writes into that one shared object; every gate (`job_detail_screen.dart`, the messaging button in `profile_detail_screen.dart`) reads or listens to the same instance via `ValueListenableBuilder`, so state is consistent everywhere immediately — including screens already open on the navigation stack, not just freshly opened ones.
   - Plain user IDs (which never change) were left as ordinary strings — only the mutable `subscription_status` needed this treatment. Kept the fix scoped to what was actually broken rather than introducing a general state-management library.
3. Small completeness addition alongside the fix: a "Subscribed" chip on the own-profile card — previously there was no UI signal anywhere that a user had subscribed except gated buttons quietly changing what they did.

`flutter analyze` clean throughout the refactor (touched 7 files).

**What's still broken or incomplete:**
- Same run gap as always — this fix is logically verified (careful reading, consistent reference-passing pattern, clean analyze) but not watched running.
- `HomeShell`'s `IndexedStack` still eagerly builds and fetches all 5 tabs on load — noted last session too, still fine at this data size.
- Didn't do a line-by-line visual/spacing pass (typography, color consistency, empty-state wording) — treated "fix bugs" as the higher-priority half of Day 8 given no way to visually inspect spacing from here; correctness issues are worth more than polish issues when you can only verify one of them.

**Scope decisions:**
- Treated the paywall bug as squarely in scope for "fix bugs from rushed builds" rather than restraint-worthy scope creep — it's a real, reproducible defect in the single feature the whole business model depends on (per the Master Plan doc: "direct messaging — gated behind subscription — main monetization mechanism"). Fixing it was proportionate to its severity, not a nice-to-have.
- Kept the fix minimal: a shared `ValueNotifier` for the one piece of state that's actually checked in multiple places, not a full app-wide state management rewrite.

**Next step:** Day 9 (Tue 22 Sep) — Full walkthrough test, prepare demo script, fix critical bugs.

---

## 2026-09-15 — Session 11: Demo script + a critical data bug (Day 9)

"Full walkthrough test" means clicking through the running app — this container still can't do that (no route to `supabase.co`), so the walkthrough was done by tracing every screen's logic against the actual live data, step by step, as if following the demo script by hand.

**What got built/changed:**
- **Found and fixed a real demo-breaking bug**: all 5 documented "DEMO VERIFICATION TEST EMAILS" — the exact accounts every prior session's notes and the seed file itself tell you to use — were seeded `subscription_status = 'subscribed'`. Following the documented flow with any of them would never show the paywall at all, meaning the app's main monetization mechanism (per the Master Plan doc) was invisible in the one script anyone would actually follow. This wasn't caught earlier because nothing before this session had traced the *specific* combination of "which account does the script say to use" against "what does that account's data actually make possible."
  - Fixed live: flipped all 5 to `free` (verified after: 1 subscribed / 23 free). `bunga.ayu@example.com` — not one of the 5 documented accounts — deliberately left subscribed as an optional "already subscribed" reference.
  - Updated `supabase/seed.sql` to match, so a fresh install seeds correctly from now on.
- **`DEMO_SCRIPT.md`** — the actual deliverable for Sep 23: which email to use and why, the order to show features in, explicit talking points for what's real vs. mocked (say this out loud, don't let it go unsaid), the known open items worth surfacing proactively (ILUNI NIM data access, Nearby Alumni safety design, RLS), and a "something breaks live" fallback section.
- No code changes this session — `flutter analyze` clean, `dart format` reported nothing to change. This session's walkthrough surfaced a data/content problem, not a logic bug.

**What's still broken or incomplete:**
- Still no way to actually watch this run from this container — the walkthrough and the demo script are both grounded in reading the code and querying live data, not in having pressed the buttons.
- Didn't independently re-verify the whole golden path from zero (fresh browser, no cached state) — traced it by reading, which is a real check but not the same as a live run.

**Scope decisions:**
- Treated the pre-subscribed test accounts as a critical bug worth fixing now rather than just noting for later — it directly undermines the single most important thing the demo needs to show, and Day 9 exists specifically to catch exactly this kind of issue before the 23rd.
- Wrote the demo script assuming the presenter (Farrel) hasn't personally re-tested every step either — spelled out fallback behavior and what to say if something breaks, rather than assuming a dry run happened.

**Next step:** Day 10 (Wed 23 Sep) — Buffer + demo day. No more build days after this one in the current plan.

---

## 2026-09-15 — Session 12: Full code re-evaluation + business assessment

User asked for a fresh pass over all code with bug fixes, then a business-point-of-view assessment (delivered in chat).

**What got fixed (all real, all demo-visible):**
- **Chat tab was permanently stale.** `MessagesListScreen` fetched once at shell load; `IndexedStack` keeps tabs alive, so a conversation started from the directory never showed on the Chat tab — the demo script's own step 6.4 would have failed live. `HomeShell` now recreates the Jobs and Chat tabs (via a bumped `ValueKey`) when they're re-selected, forcing a refetch.
- **Chat thread flickered to a spinner on every send** and anchored the newest message at the bottom of a non-reversed list. Rewrote `ChatScreen` to hold messages in state (list stays on screen during refetch), `reverse: true` (newest always in view), plus a refresh action so the other participant's replies are visible.
- **No sign-out.** Added a sign-out action on the own-profile AppBar (`pushAndRemoveUntil` back to verification), which also makes the "show both sides of a conversation" demo beat possible.
- Removed the dead `supabase` global in `main.dart`; replaced the boilerplate README with real run/test-account/database instructions (`DEMO_SCRIPT.md` was pointing at it).

**Reviewed and left alone (no bug found):** verification, profile setup, post-job, subscribe, job detail, directory filters (`DropdownButtonFormField.initialValue` is valid on this SDK and the option lists are de-duplicated, so no duplicate-value assertion risk), announcements, the shared `ValueNotifier` wiring from Session 10.

**Still not verified by running** — same limitation as every session since Day 4. Everything above is by code reading and `flutter analyze`.

**Next step:** someone runs `DEMO_SCRIPT.md` end to end in a browser before the 23rd.

---

## 2026-09-15 — Session 13: Branded welcome screen + pitch landing page

**What got built:**
- Published a pitch landing page (Claude Artifact, shared with the user separately, not part of this repo) — placeholder visual identity: indigo/brass palette drawn from Javanese batik (kawung motif, indigo-dyed cloth, brass prada gilding), Fraunces + IBM Plex Sans, content mirroring the real pitch deck and app structure. Explicitly labeled placeholder in its footer.
- Carried that identity into the app itself: `lib/theme.dart` (custom ColorScheme, Fraunces/Plex TextTheme via new `google_fonts` dependency), `lib/kawung_mark.dart` (CustomPainter brand mark), `lib/screens/welcome_screen.dart` (new entry screen: mark, wordmark, the pitch deck's own headline, one CTA into the unchanged `VerificationScreen`, explicit demo/placeholder-branding footnote). `main.dart` now opens on `WelcomeScreen` with `AppTheme.light()` instead of the plain deepPurple Material default.
- `flutter analyze` clean.

**What's still broken or incomplete:**
- `google_fonts` fetches font files over the network at first use — same requirement the app already has for Supabase, but worth knowing if testing somewhere with restricted egress.
- Only `VerificationScreen`'s header icon and everything downstream (HomeShell, directory, jobs, etc.) still use the old deepPurple-seeded implicit styling in places — the new palette flows through `Theme.of(context)` app-wide via `AppTheme.light()`, but nothing was individually re-touched beyond the new welcome screen. Should look consistent since it's all theme-driven, not verified by running.
- Same run gap as always.

**Scope decisions:**
- Interpreted "replacing the current connected to database screen" as the app's entry screen in general (that literal diagnostic screen was already removed in Session 10) — added a proper branded landing screen in front of the existing verification form rather than restyling the form itself, since a landing page's job is the CTA moment, not the form.

**Next step:** demo day. No further build days in the current plan.

---

## 2026-09-15 — Session 14: Owner demo account + basic RLS + public deploy attempt

User asked to (1) seed a dummy alumni account under their own real email with made-up profile details, and (2) deploy the app publicly on Vercel for the demo.

**Seeded account:** `farrel.abi.saleh@gmail.com`, NIM `24010119130099`, "Farrel Alfarabi Saleh" — employer/role/industry are fabricated for the demo. Added to `supabase/seed.sql` and inserted live.

**RLS — added, but scoped honestly:** Before deploying publicly, checked whether RLS could actually protect alumni data. It can't, on this codebase as it stands: `verification_screen.dart` never creates a real Supabase Auth session — "verification" is a plain email match, and every request (app or otherwise) hits Postgres as the same anon principal. RLS can't distinguish "the app" from "any visitor with the anon key." Flagged this to the user with the real tradeoff (cheap guardrails now vs. build real auth first vs. deploy fully open) — they chose cheap guardrails now.

`supabase/migrations/20260915120000_add_basic_rls.sql` — enabled RLS on all 5 tables, applied live to project `kdmxgtwqqnlbgfcpdivp`:
- No DELETE possible anywhere (app never deletes).
- No INSERT on `alumni_profiles` (app only matches existing seeded rows).
- UPDATE on `alumni_profiles` locked via trigger (`alumni_profiles_restrict_update`) to only the columns the app writes (`verification_status`, `subscription_status`, `current_employer`, `current_role`, `industry`, `company`) — name/email/nim/faculty/major/graduation_year can't be overwritten by a stray request.
- `job_posts` / `conversations` / `messages`: select + insert open (matches the app's actual usage), no update/delete.
- `announcements`: select only.
- Closed a `get_advisors`-flagged hole: the trigger function was `SECURITY DEFINER` and, by Postgres default, directly callable as a PostgREST RPC by `anon`/`authenticated`/`public`. Revoked execute on it from all three.

Verified every path by hand against the live project (`set role anon`): confirmed reads still work, confirmed the app's actual write paths (subscription update, profile-fields update, job post insert) still succeed, and confirmed delete / fake-profile insert / identity-column update are all rejected. `get_advisors` security check is clean after the revoke.

**What this does NOT fix:** the alumni directory (names, emails, employers) and all messages remain fully world-readable to anyone with the anon key once this is public — that requires real authentication, which was explicitly deferred (see the RLS migration's own header comment for the reasoning).

**Deploy status:** [fill in after the Vercel attempt below resolves].
