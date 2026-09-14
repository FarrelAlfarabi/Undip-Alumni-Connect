-- ============================================================================
-- Initial schema — UNDIP Alumni Connect MVP demo
--
-- DEMO SCOPE NOTICE:
-- This migration intentionally ships WITHOUT Row Level Security (RLS)
-- policies and without any security hardening. NIM verification is a plain
-- exact-string-match against seeded dummy data (no real institutional
-- verification), and subscription_status is a visual/demo flag only — there
-- is no real payment or billing logic behind it. RLS and security hardening
-- are explicitly deferred to post-demo, per project decisions in
-- PROJECT_NOTES.md. Do not treat this schema as production-ready.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- alumni_profiles
-- One row per alumnus. NIM is the exact-match key used by the demo's
-- "verification" flow at signup.
-- ----------------------------------------------------------------------------
create table if not exists alumni_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id),
  nim text not null unique,
  name text not null,
  faculty text not null,
  major text not null,
  graduation_year integer not null,
  current_employer text,
  current_role text,
  industry text,
  company text,
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified', 'verified', 'failed')),
  -- Visual/demo only — no real billing behind this. See notice above.
  subscription_status text not null default 'free'
    check (subscription_status in ('free', 'subscribed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_alumni_profiles_faculty on alumni_profiles (faculty);
create index if not exists idx_alumni_profiles_graduation_year on alumni_profiles (graduation_year);
create index if not exists idx_alumni_profiles_industry on alumni_profiles (industry);
create index if not exists idx_alumni_profiles_company on alumni_profiles (company);

-- ----------------------------------------------------------------------------
-- job_posts
-- Visible to all alumni. Contact details are gated behind subscription in
-- the app layer for the demo (no RLS enforcement yet).
-- ----------------------------------------------------------------------------
create table if not exists job_posts (
  id uuid primary key default gen_random_uuid(),
  posted_by uuid references alumni_profiles (id),
  title text not null,
  company text not null,
  industry text,
  description text not null,
  contact_info text,
  created_at timestamptz not null default now()
);

create index if not exists idx_job_posts_industry on job_posts (industry);
create index if not exists idx_job_posts_company on job_posts (company);

-- ----------------------------------------------------------------------------
-- conversations / messages
-- Direct messaging between two alumni, gated behind subscription in the
-- app layer for the demo (no RLS enforcement yet).
-- ----------------------------------------------------------------------------
create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  participant_one uuid not null references alumni_profiles (id),
  participant_two uuid not null references alumni_profiles (id),
  created_at timestamptz not null default now(),
  constraint distinct_participants check (participant_one <> participant_two)
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations (id),
  sender_id uuid not null references alumni_profiles (id),
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_messages_conversation_id on messages (conversation_id);

-- ----------------------------------------------------------------------------
-- announcements
-- One-way broadcast, no moderation for the demo.
-- ----------------------------------------------------------------------------
create table if not exists announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  posted_by uuid references alumni_profiles (id),
  created_at timestamptz not null default now()
);
