-- ============================================================================
-- Seed data — job_posts (Day 5 demo)
--
-- A handful of realistic job posts tied to existing seeded alumni, so the
-- job board isn't empty for the demo. Posters chosen so the job fits their
-- seeded employer (Ahmad @ Gojek, Siti @ Bank Mandiri, Reza @ Tokopedia).
--
-- Depends on supabase/seed.sql having run first (needs those alumni rows
-- to exist). Not idempotent-guarded by a unique key the way seed.sql is —
-- re-running this will insert duplicates. Safe to run once against a
-- freshly seeded database.
-- ============================================================================

insert into job_posts (posted_by, title, company, industry, description, contact_info)
values
  (
    (select id from alumni_profiles where email = 'ahmad.ramadhan@example.com'),
    'Product Manager',
    'Gojek',
    'Technology',
    'Looking for a Product Manager to lead our merchant tools team. UNDIP alumni preferred — reach out directly.',
    'ahmad.ramadhan@example.com'
  ),
  (
    (select id from alumni_profiles where email = 'siti.azizah@example.com'),
    'Business Analyst',
    'Bank Mandiri',
    'Banking & Finance',
    'Entry to mid-level Business Analyst role in our digital banking division. Fresh grads welcome.',
    'siti.azizah@example.com'
  ),
  (
    (select id from alumni_profiles where email = 'reza.putra@example.com'),
    'Backend Engineer',
    'Tokopedia',
    'Technology',
    'Backend Engineer for our logistics platform team. Go or Java experience a plus.',
    'reza.putra@example.com'
  );
