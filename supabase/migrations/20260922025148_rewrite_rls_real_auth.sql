-- ============================================================================
-- Real Row Level Security, stage 2: replace the vandalism-guardrail-only
-- policies from 20260915120000_add_basic_rls.sql (and later migrations)
-- with real per-user access control, now that real Supabase Auth sessions
-- exist (see 20260922090000_add_auth_claim_function.sql).
--
-- Scope, per the production-hardening plan: alumni_profiles, job_posts,
-- conversations, and messages. Profile read stays open (the directory
-- needs it, and pre-login "does this email exist" check also needs it) —
-- only writes are scoped to auth.uid(). The headline change: messages are
-- now only readable by a real participant of the conversation, checked
-- against a real auth.uid(), not a client-supplied id anyone could pass.
--
-- Known residual gap, explicitly not touched here since it's out of this
-- migration's stated scope: notifications, job_applications,
-- city_chat_messages, and email_log still use the old open
-- guardrail-only policies (select/insert true). That means, e.g., any
-- authenticated user can currently read any other user's job-application
-- notifications or the full job_applications table. Flagged in
-- PROJECT_NOTES.md as a follow-up, not fixed here to stay in scope.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- alumni_profiles
-- Select stays open (directory browsing + the pre-auth "does this alumni
-- exist" check in the verification flow both need it). Update is now
-- scoped to the caller's own linked row. The first-time link (user_id
-- null -> auth.uid()) can't go through this policy — see
-- claim_alumni_profile(), which is SECURITY DEFINER specifically for that.
-- ----------------------------------------------------------------------------
drop policy if exists "alumni_profiles_update" on alumni_profiles;

create policy "alumni_profiles_update" on alumni_profiles
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- job_posts
-- Select stays open (public job board). Insert now requires posting as
-- your own linked alumni_profiles row, not an arbitrary posted_by id.
-- ----------------------------------------------------------------------------
drop policy if exists "job_posts_insert" on job_posts;

create policy "job_posts_insert" on job_posts
  for insert
  to authenticated
  with check (
    exists (
      select 1 from alumni_profiles p
      where p.id = posted_by and p.user_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- conversations
-- No longer world-readable/insertable: a conversation reveals who is
-- messaging whom, so only its two participants may see or create it.
-- ----------------------------------------------------------------------------
drop policy if exists "conversations_select" on conversations;
drop policy if exists "conversations_insert" on conversations;

create policy "conversations_select" on conversations
  for select
  to authenticated
  using (
    exists (
      select 1 from alumni_profiles p
      where p.user_id = auth.uid()
        and p.id in (conversations.participant_one, conversations.participant_two)
    )
  );

create policy "conversations_insert" on conversations
  for insert
  to authenticated
  with check (
    exists (
      select 1 from alumni_profiles p
      where p.user_id = auth.uid()
        and p.id in (participant_one, participant_two)
    )
  );

-- ----------------------------------------------------------------------------
-- messages
-- The headline requirement: a user can only read messages belonging to a
-- conversation they are actually a participant in, and can only send a
-- message as their own linked profile into a conversation they're part of.
-- ----------------------------------------------------------------------------
drop policy if exists "messages_select" on messages;
drop policy if exists "messages_insert" on messages;

create policy "messages_select" on messages
  for select
  to authenticated
  using (
    exists (
      select 1 from conversations c
      join alumni_profiles p
        on p.id in (c.participant_one, c.participant_two)
      where c.id = messages.conversation_id
        and p.user_id = auth.uid()
    )
  );

create policy "messages_insert" on messages
  for insert
  to authenticated
  with check (
    exists (
      select 1 from alumni_profiles p
      where p.id = sender_id and p.user_id = auth.uid()
    )
    and exists (
      select 1 from conversations c
      where c.id = conversation_id
        and (c.participant_one = sender_id or c.participant_two = sender_id)
    )
  );
