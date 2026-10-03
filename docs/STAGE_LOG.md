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
