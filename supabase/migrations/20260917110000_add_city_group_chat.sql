-- ============================================================================
-- City group chat (added 17 Sep 2026, demo version of Master Plan §3.4
-- item 6's "easy way to network with nearby alumni instead of chatting
-- one by one" note).
--
-- One group per city (implicit -- there's no separate "group" entity,
-- just messages tagged with a city string). Any verified alumnus can
-- read and post to any city's chat; there's no membership list or invite
-- flow. Same "guardrail not access control" RLS limitation as the rest
-- of this schema applies here too: since there's no real Supabase Auth
-- session (see prior RLS migrations' comments), RLS can't restrict who
-- reads/posts to a given city's messages, only block destructive ops.
-- ============================================================================

create table if not exists city_chat_messages (
  id uuid primary key default gen_random_uuid(),
  city text not null,
  sender_id uuid not null references alumni_profiles (id),
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_city_chat_messages_city on city_chat_messages (city);

alter table city_chat_messages enable row level security;

create policy "city_chat_messages_select" on city_chat_messages
  for select using (true);

create policy "city_chat_messages_insert" on city_chat_messages
  for insert with check (true);
