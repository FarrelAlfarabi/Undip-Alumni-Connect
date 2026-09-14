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
