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
