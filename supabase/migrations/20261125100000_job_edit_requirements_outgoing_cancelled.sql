-- ============================================================================
-- Two small fixes from the 17 Nov test sheet (25 Nov 2026).
--
--   * B18: the job owner can change the required documents (CV, LinkedIn,
--     portfolio, cover note) when editing. job_post_update gets four extra
--     arguments. They default to null, which keeps the stored value. The old
--     6 argument version is dropped so the call is never ambiguous.
--   * A09: the sender now sees a cancelled request as "Dibatalkan" in their
--     own list. contact_requests_outgoing no longer hides cancelled rows. The
--     receiver's list (contact_requests_incoming) still hides them.
--
-- Idempotent. Rollback: supabase/rollback_job_edit_requirements_outgoing_cancelled.sql
-- ============================================================================

drop function if exists job_post_update(uuid, uuid, text, text, text, text);

create or replace function job_post_update(
  p_owner uuid, p_job uuid, p_title text, p_company text,
  p_description text, p_contact text,
  p_require_cv boolean default null,
  p_require_linkedin boolean default null,
  p_require_portfolio boolean default null,
  p_require_cover_note boolean default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  perform assert_caller(p_owner);
  select posted_by into v_owner from job_posts where id = p_job for update;
  if not found then raise exception 'not_found'; end if;
  if v_owner is distinct from p_owner then raise exception 'not_owner'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 2 and 120
     or char_length(btrim(coalesce(p_company, ''))) not between 1 and 120
     or char_length(btrim(coalesce(p_description, ''))) not between 1 and 5000
     or char_length(coalesce(p_contact, '')) > 300 then
    raise exception 'invalid_input';
  end if;
  update job_posts
     set title = btrim(p_title), company = btrim(p_company),
         description = btrim(p_description),
         contact_info = nullif(btrim(coalesce(p_contact, '')), ''),
         require_cv = coalesce(p_require_cv, require_cv),
         require_linkedin = coalesce(p_require_linkedin, require_linkedin),
         require_portfolio = coalesce(p_require_portfolio, require_portfolio),
         require_cover_note = coalesce(p_require_cover_note, require_cover_note)
   where id = p_job;
end;
$$;

revoke execute on function job_post_update(uuid, uuid, text, text, text, text,
  boolean, boolean, boolean, boolean) from public;
grant execute on function job_post_update(uuid, uuid, text, text, text, text,
  boolean, boolean, boolean, boolean) to anon, authenticated;

create or replace function contact_requests_outgoing(p_requester uuid)
returns table (
  id uuid,
  target_id uuid,
  target_name text,
  status text,
  created_at timestamptz,
  responded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform assert_caller(p_requester);
  return query
select r.id, r.target_id, p.name, r.status, r.created_at, r.responded_at
    from contact_requests r
    join alumni_profiles p on p.id = r.target_id
    where r.requester_id = p_requester
    order by r.created_at desc;
end;
$$;
