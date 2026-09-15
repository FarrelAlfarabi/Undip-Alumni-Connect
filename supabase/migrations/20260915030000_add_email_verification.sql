-- ============================================================================
-- Add email column — UNDIP Alumni Connect MVP demo
--
-- SCOPE CHANGE (14 Sep, post-Gilang meeting): the demo's verification
-- method switched from NIM exact-match to email exact-match. This
-- migration adds `email` without touching `nim` — nim stays a real
-- profile field (used in the full production spec), it's just no longer
-- the verification key for the demo.
--
-- DEMO SCOPE NOTICE: verification is still a plain exact-string-match
-- against seeded dummy data, now on email instead of nim. No real email
-- sending or OTP — same dummy-data demo scope as before. RLS and security
-- hardening remain deferred to post-demo, per project decisions in
-- PROJECT_NOTES.md.
--
-- NOTE ON CONSTRAINTS: the target shape is `email text not null unique`,
-- but the 24 existing rows have no email value yet, so NOT NULL can't be
-- added in this migration without breaking the existing data. This
-- migration adds the column nullable; the follow-up migration
-- (20260915031500_backfill_email_and_enforce.sql) backfills all 24 rows
-- via seed.sql and then adds the NOT NULL + UNIQUE constraints once every
-- row actually has a value.
-- ============================================================================

alter table alumni_profiles
  add column email text;
