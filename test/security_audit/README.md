# Security audit proof tests

Stage 5A proved each finding it could with a test that **passes only while the
weakness is present**. When Part B fixed a weakness, its proof was removed and
replaced by a test in `test/security_fixes/` that fails without the fix.

- Dart-layer proofs (SA-12, SA-13, SA-14, SA-19): all fixed, so none remain here.
- Database-side proofs: `supabase/tests/security_audit/run_audit.sh pre` (before
  the hardening migration) and `... post` (after it). They run only against a
  throwaway local Postgres, never a live project.
