-- ============================================================================
-- Stage 6: categories you can add in the dashboard (30 Oct 2026).
--
-- Until now the five categories were written into the database in three
-- places: a CHECK on marketplace_listings, a CHECK on businesses, and a list
-- inside business_register() and business_update(). Adding one needed a
-- migration. This moves the list into a table, `categories`, that Farrel edits
-- in the Supabase dashboard (add, rename, hide, reorder).
--
--   * categories(name, sort_order, active)   readable by everyone, no write
--                                            policy (dashboard only)
--   * seeded with the five old names (old rows stay valid) and the twelve new
--     ones from decision D11
--   * the two CHECKs are replaced by a foreign key (a rename cascades, a delete
--     of a used name is refused) and a trigger. A category is checked only on
--     insert and when the category of a row changes, so an item whose category
--     was hidden later can still be edited and saved. The dashboard roles
--     (postgres, service_role) skip the check.
--   * business_register() and business_update() are rewritten from their
--     current definition (pg_get_functiondef), swapping only the fixed list for
--     the same table check. business_update() skips the check when the
--     category did not change.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_categories.sql
-- ============================================================================

create table if not exists categories (
  name text primary key
    check (name = btrim(name) and char_length(name) between 1 and 60),
  sort_order integer not null default 100,
  active boolean not null default true
);

alter table categories enable row level security;

drop policy if exists "categories_read" on categories;
create policy "categories_read" on categories
  for select to anon, authenticated using (true);

revoke all on categories from anon, authenticated;
grant select on categories to anon, authenticated;

create unique index if not exists categories_name_lower_idx on categories (lower(name));

insert into categories (name, sort_order) values
  ('Food & Drink', 10),
  ('Fashion', 20),
  ('Electronics', 30),
  ('Services', 40),
  ('Home & Living', 50),
  ('Beauty & Health', 60),
  ('Education & Training', 70),
  ('Automotive', 80),
  ('Agriculture', 90),
  ('Printing & Packaging', 100),
  ('Property', 110),
  ('Travel & Hospitality', 120),
  ('Technology', 130),
  ('Pet & Garden', 140),
  ('Sports & Hobbies', 150),
  ('Art & Craft', 160),
  ('Other', 900)
on conflict (name) do nothing;

-- ---------------------------------------------------------------------------
-- The CHECK constraints on the two tables are replaced by one trigger.
-- ---------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select c.conrelid::regclass as tbl, c.conname
    from pg_constraint c
    where c.contype = 'c'
      and c.conrelid in ('marketplace_listings'::regclass, 'businesses'::regclass)
      and pg_get_constraintdef(c.oid) like '%Food & Drink%'
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
  end loop;
end $$;

do $$
begin
  if exists (
    select 1 from pg_constraint c
    where c.contype = 'c'
      and c.conrelid in ('marketplace_listings'::regclass, 'businesses'::regclass)
      and pg_get_constraintdef(c.oid) like '%Food & Drink%'
  ) then
    raise exception 'old category CHECK still present';
  end if;
end $$;

-- Renaming a category in the dashboard renames it on every item too; deleting
-- one that is in use is refused (hide it with active = false instead).
alter table marketplace_listings drop constraint if exists marketplace_listings_category_fkey;
alter table marketplace_listings add constraint marketplace_listings_category_fkey
  foreign key (category) references categories (name) on update cascade on delete restrict;
alter table businesses drop constraint if exists businesses_category_fkey;
alter table businesses add constraint businesses_category_fkey
  foreign key (category) references categories (name) on update cascade on delete restrict;

create or replace function category_must_be_active()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- The dashboard (postgres / service role) may always set any value.
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;
  if tg_op = 'INSERT' or new.category is distinct from old.category then
    if not exists (select 1 from categories where name = new.category and active) then
      raise exception 'invalid_category' using errcode = '23514';
    end if;
  end if;
  return new;
end $$;

revoke execute on function category_must_be_active() from public, anon, authenticated;

drop trigger if exists trg_marketplace_category on marketplace_listings;
create trigger trg_marketplace_category
  before insert or update of category on marketplace_listings
  for each row execute function category_must_be_active();

drop trigger if exists trg_business_category on businesses;
create trigger trg_business_category
  before insert or update of category on businesses
  for each row execute function category_must_be_active();

-- ---------------------------------------------------------------------------
-- business_register() / business_update(): same functions, new category check.
-- ---------------------------------------------------------------------------
do $$
declare
  fixed constant text :=
    'p_category is null or p_category not in (''Food & Drink'', ''Fashion'', ''Electronics'', ''Services'', ''Other'')';
  v_def text;
  v_new text;
begin
  -- Register: a new row, so the category must be on the list.
  v_def := pg_get_functiondef(
    'business_register(uuid, text, text, text, text, text, text, boolean)'::regprocedure);
  if position(fixed in v_def) > 0 then
    v_new := replace(v_def, fixed,
      'p_category is null or not exists (select 1 from categories where name = p_category and active)');
    execute v_new;
  elsif position('from categories' in v_def) = 0 then
    raise exception 'business_register: category check not found, rewrite it by hand';
  end if;

  -- Update: only a changed category has to be on the list.
  v_def := pg_get_functiondef(
    'business_update(uuid, uuid, text, text, text, text, text, boolean)'::regprocedure);
  if position(fixed in v_def) > 0 then
    v_new := replace(v_def, fixed,
      'p_category is null or (p_category is distinct from v.category and not exists (select 1 from categories where name = p_category and active))');
    execute v_new;
  elsif position('from categories' in v_def) = 0 then
    raise exception 'business_update: category check not found, rewrite it by hand';
  end if;
end $$;
