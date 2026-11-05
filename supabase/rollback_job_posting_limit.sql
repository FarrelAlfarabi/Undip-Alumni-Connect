-- Undo 20261105210000_job_posting_limit.sql. Safe to run twice.
drop trigger if exists job_posts_limit_trigger on job_posts;
drop function if exists job_posts_limit();
