-- Undo 20261105120000_admin_undo_and_counts.sql. Safe to run twice.
drop function if exists admin_business_set_state(uuid, uuid, text, text, text);
drop function if exists admin_announcement_restore(uuid, uuid, text, text, timestamptz, uuid);
drop function if exists admin_restore_bio(uuid, uuid, text);
drop function if exists admin_profile_bio(uuid, uuid);
drop function if exists admin_pending_counts(uuid);
drop function if exists admin_ikafe_contact_restore(uuid, uuid, text, text, text, integer, boolean);
-- The three functions that were changed keep working (the change only adds
-- options). To get the old bodies back, run again, in this order, the
-- function parts of: 20261003130000_app_admins.sql (admin_business_decide,
-- marketplace_review_listing), 20261018090000_suspend_user.sql
-- (admin_reports_decide).
