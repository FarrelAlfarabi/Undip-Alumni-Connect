-- Undoes supabase/migrations/20260930100000_security_hardening.sql (and the
-- admin-key migration if present). Restores the previous, weaker state
-- exactly, so only use it if the hardening broke something you need.
-- Idempotent. Never run against the shared live project without a backup.

-- admin key migration (safe if it was never applied)
alter table if exists marketplace_admins drop column if exists key_hash;
alter table if exists marketplace_admins drop column if exists failed_attempts;
alter table if exists marketplace_admins drop column if exists locked_until;

-- SA-18: restore the original review function (no reviewer columns), drop columns
drop function if exists marketplace_is_admin_key(uuid, text);
drop function if exists marketplace_admin_pending(uuid, text);
drop function if exists marketplace_review_listing(uuid, uuid, text, text, text);
drop function if exists marketplace_report_counts(uuid, text);

create or replace function marketplace_admin_pending(p_admin uuid)
returns setof marketplace_listings language plpgsql stable security definer set search_path = public as $$
begin
  if not marketplace_is_admin(p_admin) then raise exception 'not_admin'; end if;
  return query select * from marketplace_listings where status = 'pending' order by created_at asc;
end; $$;

create or replace function marketplace_review_listing(
  p_admin uuid, p_listing uuid, p_decision text, p_reason text default null
) returns marketplace_listings language plpgsql security definer set search_path = public as $$
declare v marketplace_listings;
begin
  if not marketplace_is_admin(p_admin) then raise exception 'not_admin'; end if;
  if p_decision not in ('approved', 'rejected') then raise exception 'invalid_decision'; end if;
  if p_decision = 'rejected' and nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'reason_required';
  end if;
  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if v.status <> 'pending' then raise exception 'invalid_state'; end if;
  update marketplace_listings set
    status = p_decision,
    rejected_reason = case when p_decision = 'rejected' then btrim(p_reason) else null end,
    approved_at = case when p_decision = 'approved' then now() else null end,
    updated_at = now()
  where id = p_listing returning * into v;
  return v;
end; $$;

create or replace function marketplace_report_counts(p_admin uuid)
returns table (listing_id uuid, report_count bigint) language plpgsql stable security definer set search_path = public as $$
begin
  if not marketplace_is_admin(p_admin) then raise exception 'not_admin'; end if;
  return query select r.listing_id, count(*)::bigint from marketplace_reports r group by r.listing_id order by count(*) desc;
end; $$;

revoke execute on function marketplace_admin_pending(uuid) from public;
revoke execute on function marketplace_review_listing(uuid, uuid, text, text) from public;
revoke execute on function marketplace_report_counts(uuid) from public;
grant execute on function marketplace_admin_pending(uuid) to anon, authenticated;
grant execute on function marketplace_review_listing(uuid, uuid, text, text) to anon, authenticated;
grant execute on function marketplace_report_counts(uuid) to anon, authenticated;

alter table marketplace_listings drop column if exists reviewed_by;
alter table marketplace_listings drop column if exists reviewed_at;

-- SA-16, SA-15: drop the constraints
alter table marketplace_listings drop constraint if exists marketplace_listings_image_https;
alter table messages drop constraint if exists messages_body_len;
alter table city_chat_messages drop constraint if exists city_chat_body_len;
alter table job_posts drop constraint if exists job_posts_title_len;
alter table job_posts drop constraint if exists job_posts_company_len;
alter table job_posts drop constraint if exists job_posts_industry_len;
alter table job_posts drop constraint if exists job_posts_description_len;
alter table job_posts drop constraint if exists job_posts_contact_len;
alter table job_applications drop constraint if exists job_applications_name_len;
alter table job_applications drop constraint if exists job_applications_email_len;
alter table job_applications drop constraint if exists job_applications_phone_len;
alter table job_applications drop constraint if exists job_applications_linkedin_len;
alter table job_applications drop constraint if exists job_applications_portfolio_len;
alter table job_applications drop constraint if exists job_applications_note_len;
alter table job_applications drop constraint if exists job_applications_cv_len;
alter table marketplace_listings drop constraint if exists marketplace_listings_contact_len;
alter table marketplace_listings drop constraint if exists marketplace_listings_shop_len;

-- SA-11, SA-20: original bucket setup
update storage.buckets set file_size_limit = null, allowed_mime_types = null where id = 'cvs';
drop policy if exists "cvs_public_upload" on storage.objects;
create policy "cvs_public_upload" on storage.objects for insert with check (bucket_id = 'cvs');
drop policy if exists "cvs_public_read" on storage.objects;
create policy "cvs_public_read" on storage.objects for select using (bucket_id = 'cvs');
drop policy if exists "marketplace_public_read" on storage.objects;
create policy "marketplace_public_read" on storage.objects for select using (bucket_id = 'marketplace');

-- SA-10: original notifications / email_log rights
grant insert on notifications to anon, authenticated;
grant update on notifications to anon, authenticated;
grant insert on email_log to anon, authenticated;
drop policy if exists "notifications_insert" on notifications;
create policy "notifications_insert" on notifications for insert with check (true);
drop policy if exists "email_log_insert" on email_log;
create policy "email_log_insert" on email_log for insert with check (true);
