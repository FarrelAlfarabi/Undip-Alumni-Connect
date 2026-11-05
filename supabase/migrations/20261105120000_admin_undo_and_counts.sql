-- ============================================================================
-- Admin undo and the red counts (5 Nov 2026).
--
--   * admin_business_decide: approve no longer needs a band. With no band the
--     one the owner chose is used.
--   * admin_business_set_state: puts a business back to an exact earlier
--     state (the undo of approve / reject / suspend / restore).
--   * admin_reports_decide: new action 'reopen' (undo of dismiss and
--     mark_actioned; only reports closed in the last day come back).
--   * marketplace_review_listing: new decision 'pending' (undo of a review).
--   * admin_ikafe_contact_restore: puts a deleted Kontak Ikafe row back with
--     its old id (undo of a delete).
--   * admin_announcement_restore / admin_restore_bio: undo of an announcement
--     delete and of "Hapus bio" (admin_profile_bio reads it first).
--   * admin_pending_counts: the numbers for the red tags: businesses and
--     listings waiting, unseen reports, new feedback.
--
-- Admins only (app_admin_assert), same as the other admin functions.
-- Idempotent. Rollback: supabase/rollback_admin_undo_and_counts.sql
-- ============================================================================

create or replace function admin_business_decide(
  p_admin uuid,
  p_business uuid,
  p_action text,
  p_band text default null,
  p_reason text default null
)
returns businesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v businesses;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  perform app_admin_assert(p_admin);
  if p_action is null or p_action not in ('approve', 'reject', 'suspend', 'restore') then
    raise exception 'invalid_action';
  end if;
  if char_length(coalesce(v_reason, '')) > 300 then raise exception 'reason_too_long'; end if;

  select * into v from businesses where id = p_business for update;
  if not found then raise exception 'not_found'; end if;

  if p_action = 'approve' then
    if v.status not in ('pending', 'rejected') then raise exception 'invalid_state'; end if;
    -- No band is asked of the admin: the band the owner chose is used.
    p_band := coalesce(p_band, v.requested_band);
    if p_band is null or p_band not in ('micro', 'small', 'medium', 'large') then
      raise exception 'invalid_band';
    end if;
    update businesses set status = 'approved', approved_band = p_band, rejection_reason = null,
      reviewed_by = p_admin, reviewed_at = now() where id = p_business returning * into v;
  elsif p_action = 'reject' then
    if v.status <> 'pending' then raise exception 'invalid_state'; end if;
    if v_reason is null then raise exception 'reason_required'; end if;
    update businesses set status = 'rejected', rejection_reason = v_reason,
      reviewed_by = p_admin, reviewed_at = now() where id = p_business returning * into v;
  elsif p_action = 'suspend' then
    if v.status <> 'approved' then raise exception 'invalid_state'; end if;
    update businesses set status = 'suspended', rejection_reason = v_reason,
      reviewed_by = p_admin, reviewed_at = now() where id = p_business returning * into v;
  else
    if v.status <> 'suspended' then raise exception 'invalid_state'; end if;
    if v.approved_band is null then raise exception 'invalid_band'; end if;
    update businesses set status = 'approved', rejection_reason = null,
      reviewed_by = p_admin, reviewed_at = now() where id = p_business returning * into v;
  end if;
  return v;
end;
$$;

create or replace function admin_reports_decide(
  p_admin uuid,
  p_type text,
  p_target uuid,
  p_action text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_closed text;
  v_person uuid;
  n integer;
begin
  perform app_admin_assert(p_admin);
  if p_type is null or p_type not in ('job', 'product', 'business', 'profile', 'contact_request') then
    raise exception 'invalid_type';
  end if;
  if p_action is null or p_action not in ('dismiss', 'mark_actioned', 'hide', 'restore', 'suspend_user', 'unsuspend_user', 'reopen') then
    raise exception 'invalid_action';
  end if;
  if p_action in ('suspend_user', 'unsuspend_user') and p_type not in ('profile', 'contact_request') then
    raise exception 'invalid_action';
  end if;
  if p_action in ('hide', 'restore') and p_type not in ('job', 'product', 'business') then
    raise exception 'invalid_action';
  end if;
  if p_action in ('hide', 'suspend_user') and v_reason is null then raise exception 'reason_required'; end if;
  if char_length(coalesce(v_reason, '')) > 300 then raise exception 'reason_too_long'; end if;

  if p_action in ('hide', 'restore') then
    if p_type = 'job' then
      update job_posts set hidden_at = case when p_action = 'hide' then now() end,
        hidden_reason = case when p_action = 'hide' then v_reason end where id = p_target;
    elsif p_type = 'product' then
      update marketplace_listings set hidden_at = case when p_action = 'hide' then now() end,
        hidden_reason = case when p_action = 'hide' then v_reason end where id = p_target;
    else
      update businesses set hidden_at = case when p_action = 'hide' then now() end,
        hidden_reason = case when p_action = 'hide' then v_reason end where id = p_target;
    end if;
    get diagnostics n = row_count;
    if n = 0 then raise exception 'not_found'; end if;
  end if;

  -- suspend_user / unsuspend_user (profile and contact request reports): the
  -- person is the reported profile, or the sender of the reported request.
  -- Suspending needs a reason (kept for admins), and never targets an admin.
  -- The person cannot sign in and is gone from the Directory until an admin
  -- lifts it. Open reports on the target become actioned.
  if p_action in ('suspend_user', 'unsuspend_user') then
    v_person := report_target_owner(p_type, p_target);
    if v_person is null then raise exception 'not_found'; end if;
    if p_action = 'suspend_user' then
      if v_person = p_admin or exists (select 1 from app_admins a where a.profile_id = v_person) then
        raise exception 'invalid_state';
      end if;
      update alumni_profiles set suspended_at = now(), suspended_reason = v_reason
       where id = v_person and deleted_at is null;
    else
      update alumni_profiles set suspended_at = null, suspended_reason = null
       where id = v_person and suspended_at is not null;
    end if;
    get diagnostics n = row_count;
    if n = 0 then raise exception 'not_found'; end if;
  end if;

  -- reopen: the undo of dismiss / mark_actioned (and of hide, after restore).
  -- Only reports closed in the last day come back.
  if p_action = 'reopen' then
    update content_reports set status = 'open', reviewed_by = null, reviewed_at = null
     where target_type = p_type and target_id = p_target
       and status in ('dismissed', 'actioned') and reviewed_at > now() - interval '1 day';
    if p_type = 'product' then
      update marketplace_reports set status = 'open', reviewed_by = null, reviewed_at = null
       where listing_id = p_target
         and status in ('dismissed', 'actioned') and reviewed_at > now() - interval '1 day';
    end if;
  end if;

  if p_action in ('dismiss', 'mark_actioned', 'hide', 'suspend_user') then
    v_closed := case p_action when 'dismiss' then 'dismissed' else 'actioned' end;
    update content_reports set status = v_closed, reviewed_by = p_admin, reviewed_at = now()
     where target_type = p_type and target_id = p_target and status = 'open';
    if p_type = 'product' then
      update marketplace_reports set status = v_closed, reviewed_by = p_admin, reviewed_at = now()
       where listing_id = p_target and status = 'open';
    end if;
  end if;
end;
$$;

create or replace function marketplace_review_listing(
  p_admin uuid,
  p_listing uuid,
  p_decision text,
  p_reason text default null,
  p_key text default null
)
returns marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v marketplace_listings;
begin
  perform app_admin_assert(p_admin);
  if p_decision not in ('approved', 'rejected', 'pending') then
    raise exception 'invalid_decision';
  end if;
  if p_decision = 'rejected' and nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'reason_required';
  end if;

  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if p_decision = 'approved' and v.status not in ('pending', 'rejected') then
    raise exception 'invalid_state';
  end if;
  if p_decision = 'rejected' and v.status not in ('pending', 'approved') then
    raise exception 'invalid_state';
  end if;

  -- 'pending' is the undo of a decision.
  if p_decision = 'pending' and v.status not in ('approved', 'rejected') then
    raise exception 'invalid_state';
  end if;

  update marketplace_listings set
    status = p_decision,
    rejected_reason = case when p_decision = 'rejected' then btrim(p_reason) else null end,
    approved_at = case when p_decision = 'approved' then now() else null end,
    reviewed_by = case when p_decision = 'pending' then null else p_admin end,
    reviewed_at = case when p_decision = 'pending' then null else now() end,
    updated_at = now()
  where id = p_listing
  returning * into v;

  return v;
end;
$$;

create or replace function admin_ikafe_contact_restore(
  p_admin uuid,
  p_id uuid,
  p_kind text,
  p_label text,
  p_value text,
  p_sort integer,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  if p_kind is null
     or p_kind not in ('whatsapp', 'email', 'instagram', 'linkedin', 'website')
     or btrim(coalesce(p_label, '')) = '' or btrim(coalesce(p_value, '')) = ''
     or char_length(p_label) > 60 or char_length(p_value) > 200 then
    raise exception 'invalid_input';
  end if;
  insert into ikafe_contacts (id, kind, label, value, sort_order, active)
    values (p_id, p_kind, btrim(p_label), btrim(p_value), coalesce(p_sort, 0), coalesce(p_active, true))
    on conflict (id) do nothing;
end;
$$;

create or replace function admin_business_set_state(
  p_admin uuid,
  p_business uuid,
  p_status text,
  p_band text,
  p_reason text
)
returns businesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v businesses;
begin
  perform app_admin_assert(p_admin);
  if p_status is null or p_status not in ('pending', 'approved', 'rejected', 'suspended') then
    raise exception 'invalid_state';
  end if;
  if p_band is not null and p_band not in ('micro', 'small', 'medium', 'large') then
    raise exception 'invalid_band';
  end if;
  update businesses set status = p_status, approved_band = p_band,
      rejection_reason = nullif(btrim(coalesce(p_reason, '')), ''),
      reviewed_by = case when p_status = 'pending' then null else p_admin end,
      reviewed_at = case when p_status = 'pending' then null else now() end
   where id = p_business
   returning * into v;
  if not found then raise exception 'not_found'; end if;
  return v;
end;
$$;

create or replace function admin_announcement_restore(
  p_admin uuid,
  p_id uuid,
  p_title text,
  p_body text,
  p_created_at timestamptz,
  p_posted_by uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  insert into announcements (id, title, body, posted_by, created_at)
    values (p_id, btrim(p_title), btrim(p_body), p_posted_by, coalesce(p_created_at, now()))
    on conflict (id) do nothing;
end;
$$;

-- Reads a bio before "Hapus bio" removes it, so the app can offer the undo.
create or replace function admin_profile_bio(p_admin uuid, p_profile uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_bio text;
begin
  perform app_admin_assert(p_admin);
  select bio into v_bio from alumni_profiles where id = p_profile;
  return v_bio;
end;
$$;
revoke execute on function admin_profile_bio(uuid, uuid) from public;
grant execute on function admin_profile_bio(uuid, uuid) to anon, authenticated;

create or replace function admin_restore_bio(p_admin uuid, p_profile uuid, p_bio text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  if char_length(coalesce(p_bio, '')) > 200 then raise exception 'invalid_input'; end if;
  update alumni_profiles set bio = p_bio, updated_at = now() where id = p_profile;
  if not found then raise exception 'not_found'; end if;
end;
$$;

create or replace function admin_pending_counts(p_admin uuid)
returns table (businesses integer, listings integer, reports integer, feedback integer)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  return query select
    (select count(*)::integer from public.businesses b where b.status = 'pending'),
    (select count(*)::integer from marketplace_listings l where l.status = 'pending'),
    admin_reports_unseen_count(p_admin)::integer,
    admin_feedback_new_count(p_admin)::integer;
end;
$$;

revoke execute on function admin_business_set_state(uuid, uuid, text, text, text) from public;
revoke execute on function admin_announcement_restore(uuid, uuid, text, text, timestamptz, uuid) from public;
revoke execute on function admin_restore_bio(uuid, uuid, text) from public;
revoke execute on function admin_ikafe_contact_restore(uuid, uuid, text, text, text, integer, boolean) from public;
grant execute on function admin_ikafe_contact_restore(uuid, uuid, text, text, text, integer, boolean) to anon, authenticated;
revoke execute on function admin_pending_counts(uuid) from public;
grant execute on function admin_business_set_state(uuid, uuid, text, text, text) to anon, authenticated;
grant execute on function admin_announcement_restore(uuid, uuid, text, text, timestamptz, uuid) to anon, authenticated;
grant execute on function admin_restore_bio(uuid, uuid, text) to anon, authenticated;
grant execute on function admin_pending_counts(uuid) to anon, authenticated;
