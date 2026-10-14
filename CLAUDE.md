# CLAUDE.md

## Project
- Flutter app "Lingkaran" (UNDIP FEB alumni, closed beta). Backend: Supabase.
- Feature flag `chatEnabled=false` in `lib/config/feature_flags.dart`.
- No subscription or fee wording anywhere in the app. Tests enforce it.
- Copy is in Indonesian. Feature names in the UI stay in English.
- Farrel must always be able to view and edit any data in the Supabase dashboard as admin.

## Commands
- Flutter is pinned to 3.47.4 (see `.github/workflows/flutter-ci.yml`).
- Setup: `cp .env.example .env && flutter pub get`
- Analyze: `flutter analyze`
- Tests: `flutter test -r failures-only` (one file: add its path). The `failures-only` reporter exists in 3.47.4.
- Release gate: `flutter test --dart-define=RELEASE_CHECK=true test/release_check_test.dart`
- SQL checks (local throwaway Postgres only, never a Supabase project):
  - `bash supabase/tests/run_fresh_chain.sh`
  - `bash supabase/tests/run_beta_local.sh`

## Work rules
- Test first: write a failing test, then the code, then run the tests.
- One stage per session. One commit per stage. Stop after the commit and wait for review.
- Never apply migrations to a live project. Never put secrets in the repo.
- Never use Haiku for SQL migrations, RLS, auth, or anything that exposes user data. Use the `reviewer` subagent on those.

## Token rules (every session)
- At session start read only CLAUDE.md. Do not read `docs/` or root `*.md` files unless the task names them.
- Never read `docs/archive/`, `SECURITY_AUDIT.md`, or `docs/hub/STAGE_REPORTS.md` unless Farrel asks.
- Find code with Glob and Grep first. Read with offset and limit.
- Do not read whole files over 300 lines unless you are editing them. Do not re-read a file you just edited.
- Delegate lookups ("where is X", "what calls Y") to the `explorer` subagent.
- Run tests through the `test-runner` subagent.
  - During a stage run only the test files you touched.
  - Run the full suite once, before the commit.
  - Use `-r failures-only` to keep output short.
- Do not paste long logs. Report only failing tests with file and line.
- Do not repeat a command whose inputs did not change.
- Keep replies short. Final message: what changed, what to review, 10 lines or fewer. No recap of steps.
- Do not create new docs unless asked.
- Add a stage entry to `docs/STAGE_LOG.md` of 5 lines or fewer.
  - When the log holds more than 5 stages, move older ones into `docs/archive/STAGE_LOG_ARCHIVE.md` as a short summary.
- Suggest `/clear` between stages and `/compact` if the session gets long.
- Models: main session on Sonnet. Haiku only for the `test-runner` and `explorer` subagents.
