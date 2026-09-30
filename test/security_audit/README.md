# Security audit proof tests (Stage 5A)

These tests **demonstrate weaknesses** found in `SECURITY_AUDIT.md`. Each one
passes today because the weakness is present. They run against fakes and local
files only, never against a live project. In Part B a fix flips the assertion
(see `test/security_fixes/`), so the same check fails before the fix and
passes after it.

The database-side proofs live in `supabase/tests/security_audit/` (run
`bash supabase/tests/security_audit/run_audit.sh pre`).
