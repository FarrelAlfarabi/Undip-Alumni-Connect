-- Home order (Stage 5, 30 Oct 2026): admins choose which products and jobs
-- Home shows first.
--
--   * marketplace_listings.home_rank and job_posts.home_rank: null = not
--     pinned, 1..99 = place in the pinned list (1 first). Plain nullable
--     integers, so the Supabase dashboard can view and edit them as admin.
--   * Members cannot write home_rank: a trigger refuses it for the anon and
--     authenticated roles (insert and update). The owner role, the
--     dashboard and the functions below are not affected.
--   * admin_set_home_order(admin, kind, ids): saves the whole pinned list of
--     one kind in one call: ids[1] gets rank 1, ids[2] rank 2, and every other
--     item of that kind is cleared. One call is one transaction, so a failure
--     cannot leave a half-changed order. kind is 'listing' or 'job'.
--     Admins only (app_admins), same check as the other admin functions.
--   * admin_home_order_list(admin, kind): every pinned item (any status) and
--     every item Home could show, with its status, for the admin screen.
--   * No change to who can read the tables. home_rank is not secret.
--   * Editorial only: no fee, no paid placement.
--
-- Idempotent. Rollback: supabase/rollback_home_order.sql
-- Not applied to the live project by this change. Farrel applies it in the
-- SQL Editor.

alter table marketplace_listings add column if not exists home_rank integer;
alter table job_posts add column if not exists home_rank integer;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'marketplace_listings_home_rank_check') then
    alter table marketplace_listings
      add constraint marketplace_listings_home_rank_check
      check (home_rank is null or home_rank between 1 and 99);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'job_posts_home_rank_check') then
    alter table job_posts
      add constraint job_posts_home_rank_check
      check (home_rank is null or home_rank between 1 and 99);
  end if;
end $$;

-- Members (anon and authenticated, the only roles the app uses) must not set
-- or change home_rank. Functions below run as the owner, so they pass.
create or replace function home_rank_members_cannot_write()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' and new.home_rank is not null then
      raise exception 'home_rank can only be set by an admin';
    elsif tg_op = 'UPDATE' and new.home_rank is distinct from old.home_rank then
      raise exception 'home_rank can only be set by an admin';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function home_rank_members_cannot_write() from public, anon, authenticated;

drop trigger if exists marketplace_listings_home_rank_guard on marketplace_listings;
create trigger marketplace_listings_home_rank_guard
  before insert or update on marketplace_listings
  for each row execute function home_rank_members_cannot_write();

drop trigger if exists job_posts_home_rank_guard on job_posts;
create trigger job_posts_home_rank_guard
  before insert or update on job_posts
  for each row execute function home_rank_members_cannot_write();

create or replace function admin_set_home_order(p_admin uuid, p_kind text, p_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  ids uuid[] := coalesce(p_ids, array[]::uuid[]);
  n integer := coalesce(array_length(ids, 1), 0);
  found_count integer;
begin
  perform app_admin_assert(p_admin);
  if p_kind is null or p_kind not in ('listing', 'job') then
    raise exception 'invalid_kind';
  end if;
  if n > 99 or n <> (select count(distinct x) from unnest(ids) x) then
    raise exception 'invalid_input';
  end if;

  if p_kind = 'listing' then
    select count(*) into found_count from marketplace_listings where id = any (ids);
    if found_count <> n then raise exception 'not_found'; end if;
    update marketplace_listings m
       set home_rank = o.ord
      from unnest(ids) with ordinality as o(id, ord)
     where m.id = o.id and m.home_rank is distinct from o.ord::integer;
    update marketplace_listings
       set home_rank = null
     where home_rank is not null and not (id = any (ids));
  else
    select count(*) into found_count from job_posts where id = any (ids);
    if found_count <> n then raise exception 'not_found'; end if;
    update job_posts j
       set home_rank = o.ord
      from unnest(ids) with ordinality as o(id, ord)
     where j.id = o.id and j.home_rank is distinct from o.ord::integer;
    update job_posts
       set home_rank = null
     where home_rank is not null and not (id = any (ids));
  end if;
end;
$$;
revoke execute on function admin_set_home_order(uuid, text, uuid[]) from public;
grant execute on function admin_set_home_order(uuid, text, uuid[]) to anon, authenticated;

-- status: for products 'hidden' (hidden by an admin or its business is not
-- visible), else the listing status (pending, approved, rejected, sold); for
-- jobs 'hidden' or 'active'.
create or replace function admin_home_order_list(p_admin uuid, p_kind text)
returns table (
  id uuid,
  title text,
  owner_name text,
  status text,
  home_rank integer,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform app_admin_assert(p_admin);
  if p_kind is null or p_kind not in ('listing', 'job') then
    raise exception 'invalid_kind';
  end if;
  if p_kind = 'listing' then
    return query
      select m.id, m.title, p.name,
             case when m.hidden_at is not null or not marketplace_business_visible(m.business_id)
                  then 'hidden' else m.status end,
             m.home_rank, m.created_at
        from marketplace_listings m
        join alumni_profiles p on p.id = m.seller_id
       where m.home_rank is not null
          or (m.status = 'approved' and m.hidden_at is null
              and marketplace_business_visible(m.business_id))
       order by m.home_rank asc nulls last, m.created_at desc;
  else
    return query
      select j.id, j.title, coalesce(nullif(j.company, ''), p.name),
             case when j.hidden_at is not null then 'hidden' else 'active' end,
             j.home_rank, j.created_at
        from job_posts j
        left join alumni_profiles p on p.id = j.posted_by
       where j.home_rank is not null or j.hidden_at is null
       order by j.home_rank asc nulls last, j.created_at desc;
  end if;
end;
$$;
revoke execute on function admin_home_order_list(uuid, text) from public;
grant execute on function admin_home_order_list(uuid, text) to anon, authenticated;
