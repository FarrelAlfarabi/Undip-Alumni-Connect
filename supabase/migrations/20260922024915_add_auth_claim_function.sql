-- ============================================================================
-- Real authentication, stage 1: link a Supabase Auth session to its
-- alumni_profiles row.
--
-- Replaces the old "verification" flow (a plain email exact-match that
-- never created a real session — see 20260915030000_add_email_verification.sql
-- and every prior PROJECT_NOTES entry calling this out as demo-only) with
-- real Supabase Auth: the client sends an email OTP via
-- `signInWithOtp`/`verifyOTP`, and once that succeeds, calls this RPC to
-- link the resulting `auth.users` row to the matching `alumni_profiles`
-- row by email.
--
-- Why an RPC instead of a plain client-side UPDATE: `alumni_profiles.user_id`
-- starts NULL for every seeded row, so the very first claim can't satisfy
-- an `auth.uid() = user_id` RLS check (see the next migration) — nothing
-- would ever match. This function runs SECURITY DEFINER specifically so it
-- can perform that one first-time link, but it does its own precise
-- authorization check internally (only the row matching the caller's own
-- authenticated email, and only while unclaimed) rather than relying on
-- table-level RLS for this one operation.
-- ============================================================================

create or replace function claim_alumni_profile()
returns alumni_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_row alumni_profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select email into v_email from auth.users where id = v_uid;
  if v_email is null then
    raise exception 'No authenticated email found for this session';
  end if;

  select * into v_row
  from alumni_profiles
  where lower(email) = lower(v_email)
    and (user_id is null or user_id = v_uid)
  order by (user_id = v_uid) desc
  limit 1;

  if not found then
    raise exception 'No matching alumni record for this email';
  end if;

  if v_row.user_id is null then
    update alumni_profiles
    set user_id = v_uid,
        verification_status = 'verified'
    where id = v_row.id
    returning * into v_row;
  end if;

  return v_row;
end;
$$;

-- Only a signed-in user can call this — anon has no session to link, and
-- the old exact-match flow (also anon) is gone.
revoke all on function claim_alumni_profile() from public, anon;
grant execute on function claim_alumni_profile() to authenticated;
