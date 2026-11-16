-- Admin permanent delete of a job or a marketplace listing.
--
-- Admins could only hide these before. Now an admin can delete one for good:
--   admin_job_delete(p_admin, p_job, p_reason)
--   admin_listing_delete(p_admin, p_listing, p_reason)
-- Both: admin only (app_admin_assert), refused while the real sign in is
-- off, a reason is required, unknown id gives
-- 'not_found', and a Riwayat row (admin_actions) is written in the same
-- transaction. The job's applications (and their CV files), notifications
-- and email log rows go with it; photos and CVs are queued for removal by
-- the existing storage cleanup triggers. Reports about the item go with it,
-- as when an owner deletes their own post. Cannot be undone: the app asks for a confirm step first.
-- Idempotent. Rollback: supabase/rollback_admin_delete_posts.sql

create or replace function admin_job_delete(p_admin uuid, p_job uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_title text;
begin
  perform app_admin_assert(p_admin);
  if not login_required() then raise exception 'login_required'; end if;
  if v_reason is null then raise exception 'reason_required'; end if;
  select title into v_title from job_posts where id = p_job for update;
  if not found then raise exception 'not_found'; end if;
  delete from content_reports where target_type = 'job' and target_id = p_job;
  delete from notifications where job_post_id = p_job
     or (target_type = 'job' and target_id = p_job);
  delete from email_log where job_post_id = p_job;
  delete from job_applications where job_post_id = p_job;
  delete from job_posts where id = p_job;
  insert into admin_actions (admin_id, action, target_type, target_id, detail)
    values (p_admin, 'job_delete', 'job', p_job::text,
            left(coalesce(v_title, '-') || ': ' || v_reason, 300));
end;
$$;

create or replace function admin_listing_delete(p_admin uuid, p_listing uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_title text;
begin
  perform app_admin_assert(p_admin);
  if not login_required() then raise exception 'login_required'; end if;
  if v_reason is null then raise exception 'reason_required'; end if;
  select title into v_title from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  delete from marketplace_listings where id = p_listing;
  insert into admin_actions (admin_id, action, target_type, target_id, detail)
    values (p_admin, 'listing_delete', 'listing', p_listing::text,
            left(coalesce(v_title, '-') || ': ' || v_reason, 300));
end;
$$;

revoke execute on function admin_job_delete(uuid, uuid, text) from public;
revoke execute on function admin_listing_delete(uuid, uuid, text) from public;
grant execute on function admin_job_delete(uuid, uuid, text) to anon, authenticated;
grant execute on function admin_listing_delete(uuid, uuid, text) to anon, authenticated;
