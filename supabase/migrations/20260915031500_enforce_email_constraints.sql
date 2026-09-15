-- ============================================================================
-- Enforce NOT NULL + UNIQUE on alumni_profiles.email
--
-- Follow-up to 20260915030000_add_email_verification.sql. That migration
-- added `email` nullable because the 24 existing rows had no value yet.
-- supabase/seed.sql has since backfilled all 24 rows (verified: 24 total,
-- 24 non-null, 24 distinct), so it's now safe to turn on the constraints
-- that make email genuinely mandatory and unique, matching NIM's original
-- role.
-- ============================================================================

alter table alumni_profiles
  alter column email set not null;

alter table alumni_profiles
  add constraint alumni_profiles_email_key unique (email);
