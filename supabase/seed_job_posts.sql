-- ============================================================================
-- Seed data — job_posts (Day 5 demo)
--
-- A handful of realistic job posts tied to existing seeded alumni, so the
-- job board isn't empty for the demo. Posters chosen so the job fits their
-- seeded employer (Ahmad @ Gojek, Siti @ Bank Mandiri, Reza @ Tokopedia).
--
-- Depends on supabase/seed.sql having run first (needs those alumni rows
-- to exist).
--
-- Idempotent (fixed post-demo, matching seed.sql's own pattern): each row
-- carries a fixed seed_key, and ON CONFLICT (seed_key) DO UPDATE means
-- re-running this script against an already-seeded database updates the
-- three demo rows in place instead of duplicating them. seed_key is a
-- seed-script-only column (nullable, unique) — real job posts created
-- through the app never set it, so this doesn't constrain real posting.
-- ============================================================================

insert into job_posts (seed_key, posted_by, title, company, industry, description, contact_info)
values
  (
    'demo-pm-gojek',
    (select id from alumni_profiles where email = 'ahmad.ramadhan@example.com'),
    'Product Manager',
    'Gojek',
    'Technology',
    'Looking for a Product Manager to lead our merchant tools team. UNDIP alumni preferred — reach out directly.',
    'ahmad.ramadhan@example.com'
  ),
  (
    'demo-ba-mandiri',
    (select id from alumni_profiles where email = 'siti.azizah@example.com'),
    'Business Analyst',
    'Bank Mandiri',
    'Banking & Finance',
    'Entry to mid-level Business Analyst role in our digital banking division. Fresh grads welcome.',
    'siti.azizah@example.com'
  ),
  (
    'demo-be-tokopedia',
    (select id from alumni_profiles where email = 'reza.putra@example.com'),
    'Backend Engineer',
    'Tokopedia',
    'Technology',
    'Backend Engineer for our logistics platform team. Go or Java experience a plus.',
    'reza.putra@example.com'
  )
on conflict (seed_key) do update set
  posted_by = excluded.posted_by,
  title = excluded.title,
  company = excluded.company,
  industry = excluded.industry,
  description = excluded.description,
  contact_info = excluded.contact_info;
