-- Undo 20261003140000_reports_and_blocks.sql. Safe to run twice.
-- WARNING: drops content_reports and user_blocks (all reports and blocks) and
-- the hidden_at / hidden_reason columns. Content an admin hid becomes visible
-- again. The marketplace_reports status columns are dropped too.
drop function if exists admin_reports_decide(uuid, text, uuid, text, text);
drop function if exists admin_reports_list(uuid, text);
drop function if exists content_report_create(uuid, text, uuid, text, text);
drop trigger if exists content_reports_enforce_trigger on content_reports;
drop table if exists content_reports cascade;
drop function if exists content_reports_enforce();
drop function if exists report_target_owner(text, uuid);

drop function if exists user_blocks_list(uuid);
drop function if exists user_unblock(uuid, uuid);
drop function if exists user_block(uuid, uuid);

-- back to the Stage 6B trigger (no block check)
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

-- back to the Stage 5 directory
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
    order by b.name asc;
end;
$$;
drop table if exists user_blocks;

-- back to the Stage 6 visibility
create or replace function marketplace_business_visible(p_business uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_business is null
      or exists (select 1 from businesses where id = p_business and status = 'approved');
$$;
drop policy if exists "marketplace_listings_select_approved" on marketplace_listings;
create policy "marketplace_listings_select_approved" on marketplace_listings
  for select to anon, authenticated
  using (status = 'approved' and marketplace_business_visible(business_id));

drop policy if exists "job_posts_select" on job_posts;
create policy "job_posts_select" on job_posts for select using (true);

drop policy if exists "marketplace_reports_insert" on marketplace_reports;
create policy "marketplace_reports_insert" on marketplace_reports
  for insert to anon, authenticated
  with check (
    exists (
      select 1 from marketplace_listings l
      where l.id = listing_id and l.status = 'approved'
    )
  );
alter table marketplace_reports drop constraint if exists marketplace_reports_status_check;
alter table marketplace_reports drop column if exists status;
alter table marketplace_reports drop column if exists reviewed_by;
alter table marketplace_reports drop column if exists reviewed_at;

alter table job_posts drop column if exists hidden_at;
alter table job_posts drop column if exists hidden_reason;
alter table businesses drop column if exists hidden_at;
alter table businesses drop column if exists hidden_reason;
alter table marketplace_listings drop column if exists hidden_at;
alter table marketplace_listings drop column if exists hidden_reason;
