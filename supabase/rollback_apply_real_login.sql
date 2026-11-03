-- Rollback for 20261103120000_apply_real_login.sql. It carries the same SQL as
-- 20261013120000_real_login.sql, so the same rollback script undoes it.
-- Safe to run twice.
\ir rollback_real_login.sql
