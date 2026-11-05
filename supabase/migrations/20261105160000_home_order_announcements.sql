-- Home order for announcements: admins choose which announcements Home shows
-- first. Same model as products and jobs: home_rank null = not pinned,
-- 1..99 = place. Home reads announcements pinned first, then newest.
-- Idempotent. Rollback: supabase/rollback_home_order_announcements.sql
alter table announcements add column if not exists home_rank integer;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'announcements_home_rank_check') then
    alter table announcements
      add constraint announcements_home_rank_check
      check (home_rank is null or home_rank between 1 and 99);
  end if;
end $$;

drop trigger if exists announcements_home_rank_guard on announcements;
create trigger announcements_home_rank_guard
  before insert or update on announcements
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
  if p_kind is null or p_kind not in ('listing', 'job', 'announcement') then
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
  elsif p_kind = 'job' then
    select count(*) into found_count from job_posts where id = any (ids);
    if found_count <> n then raise exception 'not_found'; end if;
    update job_posts j
       set home_rank = o.ord
      from unnest(ids) with ordinality as o(id, ord)
     where j.id = o.id and j.home_rank is distinct from o.ord::integer;
    update job_posts
       set home_rank = null
     where home_rank is not null and not (id = any (ids));
  else
    select count(*) into found_count from announcements where id = any (ids);
    if found_count <> n then raise exception 'not_found'; end if;
    update announcements a
       set home_rank = o.ord
      from unnest(ids) with ordinality as o(id, ord)
     where a.id = o.id and a.home_rank is distinct from o.ord::integer;
    update announcements
       set home_rank = null
     where home_rank is not null and not (id = any (ids));
  end if;
end;
$$;
revoke execute on function admin_set_home_order(uuid, text, uuid[]) from public;
grant execute on function admin_set_home_order(uuid, text, uuid[]) to anon, authenticated;

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
  if p_kind is null or p_kind not in ('listing', 'job', 'announcement') then
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
  elsif p_kind = 'job' then
    return query
      select j.id, j.title, coalesce(nullif(j.company, ''), p.name),
             case when j.hidden_at is not null then 'hidden' else 'active' end,
             j.home_rank, j.created_at
        from job_posts j
        left join alumni_profiles p on p.id = j.posted_by
       where j.home_rank is not null or j.hidden_at is null
       order by j.home_rank asc nulls last, j.created_at desc;
  else
    return query
      select a.id, a.title, p.name, 'active'::text, a.home_rank, a.created_at
        from announcements a
        left join alumni_profiles p on p.id = a.posted_by
       order by a.home_rank asc nulls last, a.created_at desc
       limit 100;
  end if;
end;
$$;
revoke execute on function admin_home_order_list(uuid, text) from public;
grant execute on function admin_home_order_list(uuid, text) to anon, authenticated;
