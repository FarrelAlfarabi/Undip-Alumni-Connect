-- ============================================================================
-- Basic RLS — vandalism/corruption guardrails only (NOT access control)
--
-- IMPORTANT: this app has no real login. "Verification" (verification_screen)
-- is a plain email match against alumni_profiles — it never creates a
-- Supabase Auth session. Every request, from the app or from anyone else who
-- has the anon key, is the exact same principal to Postgres. RLS therefore
-- CANNOT hide alumni data (names, emails, employers, messages) from a
-- random visitor — the app's own directory/job-board/messaging features
-- need that same open read access to function. Real per-row access control
-- requires adding real authentication first; that is a separate, bigger
-- piece of work, deliberately deferred (see PROJECT_NOTES.md).
--
-- What this migration DOES do: stop a request (malicious or accidental)
-- from wiping or corrupting the database once it's on a public URL.
--   - No DELETE is possible anywhere (the app never deletes any row).
--   - No new alumni_profiles rows can be inserted (the app only matches
--     existing seeded rows, never creates new ones).
--   - alumni_profiles UPDATE is restricted, via trigger, to the columns the
--     app actually writes (verification_status, subscription_status,
--     current_employer, current_role, industry, company) — identity fields
--     (name, email, nim, faculty, major, graduation_year) can't be
--     overwritten by a stray request.
--   - job_posts / conversations / messages / announcements keep the same
--     read/write shape the app already uses (select + insert only, since
--     the app never updates or deletes rows in these tables).
-- ============================================================================

alter table alumni_profiles enable row level security;
alter table job_posts enable row level security;
alter table conversations enable row level security;
alter table messages enable row level security;
alter table announcements enable row level security;

-- ----------------------------------------------------------------------------
-- alumni_profiles: read open (directory feature), no insert/delete, and
-- update locked to non-identity columns via trigger below.
-- ----------------------------------------------------------------------------
create policy "alumni_profiles_select" on alumni_profiles
  for select using (true);

create policy "alumni_profiles_update" on alumni_profiles
  for update using (true) with check (true);

create or replace function alumni_profiles_restrict_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.id <> old.id
     or new.user_id is distinct from old.user_id
     or new.nim <> old.nim
     or new.name <> old.name
     or new.email is distinct from old.email
     or new.faculty <> old.faculty
     or new.major <> old.major
     or new.graduation_year <> old.graduation_year
     or new.created_at <> old.created_at
  then
    raise exception
      'Only current_employer, current_role, industry, company, verification_status and subscription_status can be updated';
  end if;
  return new;
end;
$$;

create trigger alumni_profiles_restrict_update_trigger
  before update on alumni_profiles
  for each row execute function alumni_profiles_restrict_update();

-- ----------------------------------------------------------------------------
-- job_posts: read open (job board), insert open (post-a-job feature), no
-- update/delete (the app never edits or removes a job post).
-- ----------------------------------------------------------------------------
create policy "job_posts_select" on job_posts
  for select using (true);

create policy "job_posts_insert" on job_posts
  for insert with check (true);

-- ----------------------------------------------------------------------------
-- conversations: read + insert open (start/list a DM thread), no
-- update/delete.
-- ----------------------------------------------------------------------------
create policy "conversations_select" on conversations
  for select using (true);

create policy "conversations_insert" on conversations
  for insert with check (true);

-- ----------------------------------------------------------------------------
-- messages: read + insert open (send/read a DM), no update/delete.
-- ----------------------------------------------------------------------------
create policy "messages_select" on messages
  for select using (true);

create policy "messages_insert" on messages
  for insert with check (true);

-- ----------------------------------------------------------------------------
-- announcements: read only — the app never posts one, seeded via SQL.
-- ----------------------------------------------------------------------------
create policy "announcements_select" on announcements
  for select using (true);

-- The trigger function is SECURITY DEFINER (needed so it can enforce the
-- column lock regardless of caller), which by default makes it callable
-- directly as a PostgREST RPC by anyone. It's only meant to run as a
-- trigger, so close that off.
revoke execute on function alumni_profiles_restrict_update() from public, anon, authenticated;
