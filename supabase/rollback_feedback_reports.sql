-- Undo 20261003160000_feedback_reports.sql. Safe to run twice.
-- WARNING: deletes the feedback_reports table and every feedback row.
drop function if exists admin_feedback_set_status(uuid, uuid, text);
drop function if exists admin_feedback_new_count(uuid);
drop function if exists admin_feedback_list(uuid);
drop trigger if exists feedback_reports_enforce_trigger on feedback_reports;
drop table if exists feedback_reports cascade;
drop function if exists feedback_reports_enforce();
