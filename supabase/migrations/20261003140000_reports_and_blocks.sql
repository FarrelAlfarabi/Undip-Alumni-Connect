-- ============================================================================
-- Reporting and blocking (closed beta, Stage 6D).
--
-- REPORTS
--   content_reports: a verified alumnus reports a job, product, business,
--   profile or received contact request. Enforced in the database: the
--   reporter must be a verified alumnus, cannot report their own content, and
--   has at most one OPEN report per target. The app has no direct table
--   access; it uses content_report_create().
--   The marketplace keeps its own report table and flow (marketplace_reports,
--   no data migrated). It gets a status column (default 'open') so the admin
--   can dismiss those too, and its reports show in the same admin list.
--
-- HIDING (admin decides, nothing is automatic)
--   hidden_at / hidden_reason on job_posts, businesses, marketplace_listings.
--   Hidden content disappears from every public list and detail (policies and
--   functions). Hiding a business hides all its products. Owners still see
--   their own business and products (marked hidden) so they know why.
--
-- BLOCKS
--   user_blocks (blocker, blocked, unique pair). A blocked person cannot send
--   a contact request to the blocker (enforced here), and open requests
--   between the two are closed. Hiding a blocked person from Directory,
--   Nearby, jobs, products and businesses is done by the app (and by
--   business_directory here). WITHOUT real login this is a comfort feature
--   for honest users, not security.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_reports_and_blocks.sql
-- ============================================================================

-- ------------------------------------------------------------- hidden ---
alter table job_posts add column if not exists hidden_at timestamptz;
alter table job_posts add column if not exists hidden_reason text;
alter table businesses add column if not exists hidden_at timestamptz;
alter table businesses add column if not exists hidden_reason text;
alter table marketplace_listings add column if not exists hidden_at timestamptz;
alter table marketplace_listings add column if not exists hidden_reason text;

drop policy if exists "job_posts_select" on job_posts;
create policy "job_posts_select" on job_posts
  for select using (hidden_at is null);

create or replace function marketplace_business_visible(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_business is null
      or exists (
        select 1 from businesses
        where id = p_business and status = 'approved' and hidden_at is null
      );
$$;

drop policy if exists "marketplace_listings_select_approved" on marketplace_listings;
create policy "marketplace_listings_select_approved" on marketplace_listings
  for select to anon, authenticated
  using (status = 'approved' and hidden_at is null and marketplace_business_visible(business_id));

-- ---------------------------------------------------- marketplace reports ---
alter table marketplace_reports add column if not exists status text not null default 'open';
alter table marketplace_reports add column if not exists reviewed_by uuid references alumni_profiles (id);
alter table marketplace_reports add column if not exists reviewed_at timestamptz;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'marketplace_reports_status_check') then
    alter table marketplace_reports
      add constraint marketplace_reports_status_check check (status in ('open', 'actioned', 'dismissed'));
  end if;
end $$;

drop policy if exists "marketplace_reports_insert" on marketplace_reports;
create policy "marketplace_reports_insert" on marketplace_reports
  for insert to anon, authenticated
  with check (
    status = 'open' and reviewed_by is null and reviewed_at is null
    and exists (
      select 1 from marketplace_listings l
      where l.id = listing_id and l.status = 'approved'
    )
  );

-- ------------------------------------------------------------- blocks ---
create table if not exists user_blocks (
  blocker_id uuid not null references alumni_profiles (id),
  blocked_id uuid not null references alumni_profiles (id),
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);
create index if not exists idx_user_blocks_blocked on user_blocks (blocked_id);
alter table user_blocks enable row level security;
revoke all on user_blocks from public, anon, authenticated;

-- A blocked person cannot send a request to the blocker. The error code is
-- 'blocked'; the app shows the same plain sentence as for the 30 day
-- cool-down, so the blocked person is not told.
create or replace function contact_requests_enforce()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day_start timestamptz;
begin
  if coalesce(current_setting('role', true), '') not in ('anon', 'authenticated') then
    return new;
  end if;

  if new.requester_id = new.target_id then raise exception 'cannot_request_self'; end if;

  if exists (
    select 1 from user_blocks
    where blocker_id = new.target_id and blocked_id = new.requester_id
  ) then
    raise exception 'blocked';
  end if;

  if exists (
    select 1 from contact_requests
    where requester_id = new.requester_id and target_id = new.target_id and status = 'pending'
  ) then
    raise exception 'request_already_open';
  end if;

  if exists (
    select 1 from contact_requests
    where requester_id = new.requester_id and target_id = new.target_id
      and status = 'rejected' and responded_at > now() - interval '30 days'
  ) then
    raise exception 'cooldown_active';
  end if;

  v_day_start := date_trunc('day', now() at time zone 'Asia/Jakarta') at time zone 'Asia/Jakarta';
  if (select count(*) from contact_requests
      where requester_id = new.requester_id and created_at >= v_day_start) >= 5 then
    raise exception 'daily_limit_reached';
  end if;

  return new;
end;
$$;

create or replace function user_block(p_blocker uuid, p_blocked uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_blocker is null or p_blocked is null or p_blocker = p_blocked then
    raise exception 'cannot_block_self';
  end if;
  if not business_is_verified(p_blocker) then raise exception 'not_verified'; end if;
  if not exists (select 1 from alumni_profiles where id = p_blocked) then
    raise exception 'not_found';
  end if;

  insert into user_blocks (blocker_id, blocked_id) values (p_blocker, p_blocked)
  on conflict do nothing;

  -- Open requests between the two are closed (the app shows "not accepted").
  update contact_requests
     set status = 'rejected', shared_contact = null, responded_at = now()
   where status = 'pending'
     and ((requester_id = p_blocker and target_id = p_blocked)
       or (requester_id = p_blocked and target_id = p_blocker));
end;
$$;

create or replace function user_unblock(p_blocker uuid, p_blocked uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from user_blocks where blocker_id = p_blocker and blocked_id = p_blocked;
$$;

create or replace function user_blocks_list(p_blocker uuid)
returns table (blocked_id uuid, name text, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select b.blocked_id, p.name, b.created_at
  from user_blocks b
  join alumni_profiles p on p.id = b.blocked_id
  where b.blocker_id = p_blocker
  order by b.created_at desc;
$$;

-- The directory leaves out businesses that are hidden, and businesses owned
-- by someone the viewer blocked.
create or replace function business_directory(p_viewer uuid)
returns table (
  id uuid,
  owner_id uuid,
  name text,
  description text,
  category text,
  social_link text,
  website_link text,
  approved_band text,
  created_at timestamptz,
  owner_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not business_is_verified(p_viewer) then raise exception 'not_verified'; end if;
  return query
    select b.id, b.owner_id, b.name, b.description, b.category, b.social_link,
           b.website_link, b.approved_band, b.created_at, p.name
    from businesses b
    join alumni_profiles p on p.id = b.owner_id
    where b.status = 'approved'
      and b.hidden_at is null
      and not exists (
        select 1 from user_blocks ub
        where ub.blocker_id = p_viewer and ub.blocked_id = b.owner_id
      )
    order by b.name asc;
end;
$$;

-- ------------------------------------------------------------ reports ---
create table if not exists content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references alumni_profiles (id),
  target_type text not null
    check (target_type in ('job', 'product', 'business', 'profile', 'contact_request')),
  target_id uuid not null,
  reason text not null
    check (reason in ('spam_or_scam', 'inappropriate', 'fake_or_impersonation', 'wrong_info', 'other')),
  note text check (note is null or char_length(note) <= 300),
  status text not null default 'open' check (status in ('open', 'actioned', 'dismissed')),
  reviewed_by uuid references alumni_profiles (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_content_reports_target on content_reports (target_type, target_id);
create unique index if not exists content_reports_one_open
  on content_reports (reporter_id, target_type, target_id) where status = 'open';
alter table content_reports enable row level security;
revoke all on content_reports from public, anon, authenticated;

-- Who owns the reported thing, and does it exist. For a contact request the
-- "owner" is the person who SENT it (the reporter is the one who received it).
create or replace function report_target_owner(p_type text, p_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select case p_type
    when 'job' then (select posted_by from job_posts where id = p_id)
    when 'product' then (select seller_id from marketplace_listings where id = p_id)
    when 'business' then (select owner_id from businesses where id = p_id)
    when 'profile' then (select id from alumni_profiles where id = p_id)
    when 'contact_request' then (select requester_id from contact_requests where id = p_id)
  end;
$$;
revoke execute on function report_target_owner(text, uuid) from public, anon, authenticated;

create or replace function content_reports_enforce()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  if coalesce(current_setting('role', true), '') not in ('anon', 'authenticated') then
    return new;
  end if;

  if not business_is_verified(new.reporter_id) then raise exception 'not_verified'; end if;

  v_owner := report_target_owner(new.target_type, new.target_id);
  if v_owner is null then raise exception 'target_not_found'; end if;
  if v_owner = new.reporter_id then raise exception 'cannot_report_own'; end if;
  if new.target_type = 'contact_request' and not exists (
    select 1 from contact_requests where id = new.target_id and target_id = new.reporter_id
  ) then
    raise exception 'cannot_report_own';
  end if;

  if exists (
    select 1 from content_reports
    where reporter_id = new.reporter_id and target_type = new.target_type
      and target_id = new.target_id and status = 'open'
  ) then
    raise exception 'already_reported';
  end if;

  if new.status <> 'open' or new.reviewed_by is not null or new.reviewed_at is not null then
    raise exception 'locked_column';
  end if;
  return new;
end;
$$;
revoke execute on function content_reports_enforce() from public, anon, authenticated;

drop trigger if exists content_reports_enforce_trigger on content_reports;
create trigger content_reports_enforce_trigger
  before insert on content_reports
  for each row execute function content_reports_enforce();

create or replace function content_report_create(
  p_reporter uuid,
  p_type text,
  p_target uuid,
  p_reason text,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_id uuid;
begin
  if p_type is null or p_type not in ('job', 'product', 'business', 'profile', 'contact_request') then
    raise exception 'invalid_type';
  end if;
  if p_reason is null or p_reason not in ('spam_or_scam', 'inappropriate', 'fake_or_impersonation', 'wrong_info', 'other') then
    raise exception 'invalid_reason';
  end if;
  if char_length(coalesce(v_note, '')) > 300 then raise exception 'note_too_long'; end if;

  insert into content_reports (reporter_id, target_type, target_id, reason, note)
  values (p_reporter, p_type, p_target, p_reason, v_note)
  returning id into v_id;
  return v_id;
end;
$$;

-- --------------------------------------------------------- admin side ---
-- p_view 'open': targets with open reports (content reports and marketplace
-- reports together). p_view 'hidden': everything an admin has hidden.
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

-- dismiss: open reports on the target become dismissed.
-- mark_actioned: open reports become actioned (the admin dealt with it).
-- hide (job, product, business only; reason required): hides the content,
--   open reports become actioned. Hiding a business hides its products.
-- restore (job, product, business only): shows hidden content again.
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

revoke execute on function user_block(uuid, uuid) from public;
revoke execute on function user_unblock(uuid, uuid) from public;
revoke execute on function user_blocks_list(uuid) from public;
revoke execute on function content_report_create(uuid, text, uuid, text, text) from public;
revoke execute on function admin_reports_list(uuid, text) from public;
revoke execute on function admin_reports_decide(uuid, text, uuid, text, text) from public;
grant execute on function user_block(uuid, uuid) to anon, authenticated;
grant execute on function user_unblock(uuid, uuid) to anon, authenticated;
grant execute on function user_blocks_list(uuid) to anon, authenticated;
grant execute on function content_report_create(uuid, text, uuid, text, text) to anon, authenticated;
grant execute on function admin_reports_list(uuid, text) to anon, authenticated;
grant execute on function admin_reports_decide(uuid, text, uuid, text, text) to anon, authenticated;
