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
