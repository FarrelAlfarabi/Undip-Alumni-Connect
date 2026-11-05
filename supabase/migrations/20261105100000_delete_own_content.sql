-- ============================================================================
-- Delete own content (5 Nov 2026).
--
--   * business_delete(owner, business): the owner removes their own business
--     in any status. Its products (marketplace_listings with business_id) go
--     with it; their reports go by cascade.
--   * job_post_delete(owner, job): the poster removes their own job post. Its
--     applications, notifications and email log rows go with it.
--   * admin_announcement_delete(admin, id): an admin removes an announcement.
--
-- All three are SECURITY DEFINER and check who is asking (assert_caller, plus
-- the owner or admin check). No table or policy changes. The dashboard can
-- still view and edit everything.
-- Idempotent. Rollback: supabase/rollback_delete_own_content.sql
-- ============================================================================

create or replace function business_delete(p_owner uuid, p_business uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  perform assert_caller(p_owner);
  select owner_id into v_owner from businesses where id = p_business for update;
  if not found then raise exception 'not_found'; end if;
  if v_owner <> p_owner then raise exception 'not_owner'; end if;

  delete from content_reports
   where (target_type = 'business' and target_id = p_business)
      or (target_type = 'product' and target_id in (
            select id from marketplace_listings where business_id = p_business));
  delete from marketplace_listings where business_id = p_business;
  delete from businesses where id = p_business;
end;
$$;

create or replace function job_post_delete(p_owner uuid, p_job uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  perform assert_caller(p_owner);
  select posted_by into v_owner from job_posts where id = p_job for update;
  if not found then raise exception 'not_found'; end if;
  if v_owner is distinct from p_owner then raise exception 'not_owner'; end if;

  delete from content_reports where target_type = 'job' and target_id = p_job;
  delete from job_applications where job_post_id = p_job;
  delete from notifications where job_post_id = p_job;
  delete from email_log where job_post_id = p_job;
  delete from job_posts where id = p_job;
end;
$$;

create or replace function admin_announcement_delete(p_admin uuid, p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  delete from announcements where id = p_id;
  if not found then raise exception 'not_found'; end if;
end;
$$;

revoke execute on function business_delete(uuid, uuid) from public;
revoke execute on function job_post_delete(uuid, uuid) from public;
revoke execute on function admin_announcement_delete(uuid, uuid) from public;
grant execute on function business_delete(uuid, uuid) to anon, authenticated;
grant execute on function job_post_delete(uuid, uuid) to anon, authenticated;
grant execute on function admin_announcement_delete(uuid, uuid) to anon, authenticated;
