-- Undo supabase/cutover_real_login.sql: back to the email only check. Use it
-- if the new build has a problem and you need the old one working again.
-- Safe to run twice.
update app_settings set value = 'off' where key = 'require_login';

drop policy if exists "alumni_profiles_update_anon" on alumni_profiles;
create policy "alumni_profiles_update_anon" on alumni_profiles
  for update using (true) with check (true);

drop policy if exists "job_posts_insert_anon" on job_posts;
create policy "job_posts_insert_anon" on job_posts
  for insert with check (true);

drop policy if exists "conversations_select_anon" on conversations;
create policy "conversations_select_anon" on conversations
  for select using (true);

drop policy if exists "conversations_insert_anon" on conversations;
create policy "conversations_insert_anon" on conversations
  for insert with check (true);

drop policy if exists "messages_select_anon" on messages;
create policy "messages_select_anon" on messages
  for select using (true);

drop policy if exists "messages_insert_anon" on messages;
create policy "messages_insert_anon" on messages
  for insert with check (true);

grant execute on function verify_alumni_email(text) to anon, authenticated;
