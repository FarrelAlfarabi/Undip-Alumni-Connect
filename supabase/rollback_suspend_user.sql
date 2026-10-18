-- Rollback of 20261018090000_suspend_user.sql. Safe to run twice.
-- Puts back the previous policies, trigger and functions, then drops the two
-- columns. Anyone who was suspended can sign in again.

do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'alumni_profiles'
                and column_name = 'suspended_at') then
    update alumni_profiles set suspended_at = null, suspended_reason = null
     where suspended_at is not null;
  end if;
end $$;

drop policy if exists "alumni_profiles_select" on alumni_profiles;
create policy "alumni_profiles_select" on alumni_profiles
  for select using (deleted_at is null);

do $$
begin
  if exists (select 1 from pg_policies
              where schemaname = 'public' and tablename = 'alumni_profiles'
                and policyname = 'alumni_profiles_update_anon') then
    drop policy "alumni_profiles_update_anon" on alumni_profiles;
    create policy "alumni_profiles_update_anon" on alumni_profiles
      for update using (deleted_at is null) with check (deleted_at is null);
  end if;
end $$;

drop policy if exists "alumni_profiles_update" on alumni_profiles;
create policy "alumni_profiles_update" on alumni_profiles
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from alumni_profiles
   where user_id = auth.uid() and auth.uid() is not null
   limit 1;
$$;

create or replace function business_is_verified(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from alumni_profiles
    where id = p_profile and verification_status = 'verified'
  );
$$;

create or replace function alumni_profiles_restrict_update()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if new.id <> old.id
     or new.user_id is distinct from old.user_id
     or new.nim is distinct from old.nim
     or new.name <> old.name
     or new.email is distinct from old.email
     or new.faculty <> old.faculty
     or new.major <> old.major
     or new.graduation_year <> old.graduation_year
     or new.city is distinct from old.city
     or new.created_at <> old.created_at
     or new.policy_version is distinct from old.policy_version
     or new.policy_accepted_at is distinct from old.policy_accepted_at
     or new.deleted_at is distinct from old.deleted_at
     or new.verification_status is distinct from old.verification_status
  then
    raise exception
      'Only current_employer, current_role, industry and company can be updated';
  end if;

  if new.subscription_status is distinct from old.subscription_status then
    raise exception 'subscription_status can only be changed by subscribing';
  end if;
  return new;
end;
$$;

create or replace function verify_alumni_email(p_email text)
returns setof alumni_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  r alumni_profiles;
begin
  if p_email is null or btrim(p_email) = '' then
    return;
  end if;

  select * into r
    from alumni_profiles
   where lower(email) = lower(btrim(p_email))
     and deleted_at is null;
  if not found then
    return;
  end if;

  if r.verification_status = 'unverified' then
    update alumni_profiles
       set verification_status = 'verified'
     where id = r.id
    returning * into r;
  end if;

  return next r;
end;
$$;

create or replace function claim_alumni_profile()
returns alumni_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_row alumni_profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select email into v_email from auth.users where id = v_uid;
  if v_email is null then
    raise exception 'No authenticated email found for this session';
  end if;

  select * into v_row
    from alumni_profiles
   where lower(email) = lower(btrim(v_email))
     and deleted_at is null
     and (user_id is null or user_id = v_uid)
   order by (user_id = v_uid) desc
   limit 1;

  if not found then
    raise exception 'No matching alumni record for this email';
  end if;

  if v_row.user_id is null then
    update alumni_profiles
       set user_id = v_uid,
           verification_status = case
             when verification_status = 'unverified' then 'verified'
             else verification_status end
     where id = v_row.id
    returning * into v_row;
  end if;

  return v_row;
end;
$$;

create or replace function admin_reports_list(p_admin uuid, p_view text default 'open')
returns table (
  target_type text,
  target_id uuid,
  title text,
  owner_id uuid,
  owner_name text,
  report_count integer,
  reasons text[],
  notes text[],
  last_reported timestamptz,
  is_hidden boolean,
  hidden_reason text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  if p_view is null or p_view not in ('open', 'hidden') then raise exception 'invalid_view'; end if;

  if p_view = 'open' then
    return query
      with r as (
        select c.target_type, c.target_id, c.reason, c.note, c.created_at
          from content_reports c where c.status = 'open'
        union all
        select 'product', m.listing_id,
               case m.reason when 'spam' then 'spam_or_scam' when 'prohibited' then 'inappropriate'
                             when 'misleading' then 'wrong_info' else 'other' end,
               m.note, m.created_at
          from marketplace_reports m where m.status = 'open'
      ), g as (
        select r.target_type, r.target_id, count(*)::integer as n,
               array_agg(distinct r.reason) as reasons,
               array_remove(array_agg(r.note order by r.created_at desc), null) as notes,
               max(r.created_at) as last_reported
          from r group by r.target_type, r.target_id
      )
      select g.target_type, g.target_id,
             case g.target_type
               when 'job' then (select j.title || ' (' || j.company || ')' from job_posts j where j.id = g.target_id)
               when 'product' then (select l.title from marketplace_listings l where l.id = g.target_id)
               when 'business' then (select b.name from businesses b where b.id = g.target_id)
               when 'profile' then (select p.name from alumni_profiles p where p.id = g.target_id)
               when 'contact_request' then (select coalesce(left(q.message, 80), '(no message)') from contact_requests q where q.id = g.target_id)
             end,
             report_target_owner(g.target_type, g.target_id),
             (select p.name from alumni_profiles p where p.id = report_target_owner(g.target_type, g.target_id)),
             g.n, g.reasons, g.notes, g.last_reported,
             case g.target_type
               when 'job' then (select j.hidden_at is not null from job_posts j where j.id = g.target_id)
               when 'product' then (select l.hidden_at is not null from marketplace_listings l where l.id = g.target_id)
               when 'business' then (select b.hidden_at is not null from businesses b where b.id = g.target_id)
               else false
             end,
             case g.target_type
               when 'job' then (select j.hidden_reason from job_posts j where j.id = g.target_id)
               when 'product' then (select l.hidden_reason from marketplace_listings l where l.id = g.target_id)
               when 'business' then (select b.hidden_reason from businesses b where b.id = g.target_id)
             end
      from g
      order by g.n desc, g.last_reported desc;
  else
    return query
      select 'job'::text, j.id, j.title || ' (' || j.company || ')', j.posted_by,
             (select p.name from alumni_profiles p where p.id = j.posted_by),
             (select count(*)::integer from content_reports c where c.target_type = 'job' and c.target_id = j.id),
             array[]::text[], array[]::text[], j.hidden_at, true, j.hidden_reason
        from job_posts j where j.hidden_at is not null
      union all
      select 'product', l.id, l.title, l.seller_id,
             (select p.name from alumni_profiles p where p.id = l.seller_id),
             (select count(*)::integer from content_reports c where c.target_type = 'product' and c.target_id = l.id)
               + (select count(*)::integer from marketplace_reports m where m.listing_id = l.id),
             array[]::text[], array[]::text[], l.hidden_at, true, l.hidden_reason
        from marketplace_listings l where l.hidden_at is not null
      union all
      select 'business', b.id, b.name, b.owner_id,
             (select p.name from alumni_profiles p where p.id = b.owner_id),
             (select count(*)::integer from content_reports c where c.target_type = 'business' and c.target_id = b.id),
             array[]::text[], array[]::text[], b.hidden_at, true, b.hidden_reason
        from businesses b where b.hidden_at is not null;
  end if;
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
  n integer;
begin
  perform app_admin_assert(p_admin);
  if p_type is null or p_type not in ('job', 'product', 'business', 'profile', 'contact_request') then
    raise exception 'invalid_type';
  end if;
  if p_action is null or p_action not in ('dismiss', 'mark_actioned', 'hide', 'restore') then
    raise exception 'invalid_action';
  end if;
  if p_action in ('hide', 'restore') and p_type not in ('job', 'product', 'business') then
    raise exception 'invalid_action';
  end if;
  if p_action = 'hide' and v_reason is null then raise exception 'reason_required'; end if;
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

  if p_action in ('dismiss', 'mark_actioned', 'hide') then
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

revoke execute on function alumni_profiles_restrict_update() from public, anon, authenticated;
revoke execute on function verify_alumni_email(text) from public;
grant execute on function verify_alumni_email(text) to anon, authenticated;
revoke all on function claim_alumni_profile() from public, anon;
grant execute on function claim_alumni_profile() to authenticated;
revoke execute on function admin_reports_list(uuid, text) from public;
revoke execute on function admin_reports_decide(uuid, text, uuid, text, text) from public;
grant execute on function admin_reports_list(uuid, text) to anon, authenticated;
grant execute on function admin_reports_decide(uuid, text, uuid, text, text) to anon, authenticated;

alter table alumni_profiles drop column if exists suspended_at;
alter table alumni_profiles drop column if exists suspended_reason;
