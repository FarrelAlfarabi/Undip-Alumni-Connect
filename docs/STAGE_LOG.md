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
