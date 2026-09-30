-- ============================================================================
-- Small fix, stage 4: make seed_job_posts.sql idempotent.
--
-- seed.sql already solves this with ON CONFLICT (nim) — nim is a real
-- identity column so it doubles as a natural unique key. job_posts has no
-- such natural key (two different posters can legitimately post the same
-- title at different times), so this adds a nullable seed_key column
-- instead of constraining real data: only rows inserted by the seed
-- script ever set it, real user-submitted posts leave it null (multiple
-- nulls are fine under a unique constraint), and the seed script can
-- upsert on it without touching how job posting works for real users.
-- ============================================================================

alter table job_posts add column if not exists seed_key text unique;
