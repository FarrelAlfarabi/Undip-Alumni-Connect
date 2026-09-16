-- ============================================================================
-- Per-job required application fields (18 Sep 2026, feedback from Mas
-- Gilang): the job poster can mark specific application questions as
-- mandatory instead of everything but name/email being optional for
-- every job. Combined with the LinkedIn-style multi-step apply flow
-- (see apply_job_screen.dart), the applicant can't reach the Review step
-- without filling in whatever the poster required.
-- ============================================================================

alter table job_posts add column if not exists require_cv boolean not null default false;
alter table job_posts add column if not exists require_linkedin boolean not null default false;
alter table job_posts add column if not exists require_portfolio boolean not null default false;
alter table job_posts add column if not exists require_cover_note boolean not null default false;
