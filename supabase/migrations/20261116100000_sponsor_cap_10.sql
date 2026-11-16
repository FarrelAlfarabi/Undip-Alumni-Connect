-- Home sponsor carousel: at most 10 slides (Ikafe meeting, 16 Nov 2026).
-- Same function as before with `limit 10`. Idempotent.
-- Rollback: supabase/rollback_sponsor_cap_10.sql

create or replace function home_sponsors()
returns table (id uuid, name text, image_url text, link_url text)
language sql
stable
set search_path = public
as $$
  select s.id, s.name, s.image_url, s.link_url
  from sponsors s
  order by s.rank, s.created_at, s.id
  limit 10;
$$;
