-- Own job post: close (and reopen) and edit text. A closed post is kept
-- (with its applicants) but is not shown on the Job Board or in Home.
-- Functions check who is asking (assert_caller + owner). The dashboard still
-- sees and edits everything.
-- Idempotent. Rollback: supabase/rollback_job_close_edit.sql
alter table job_posts add column if not exists closed_at timestamptz;

create or replace function job_post_set_closed(p_owner uuid, p_job uuid, p_closed boolean)
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
  if v_owner <> p_owner then raise exception 'not_owner'; end if;
  update job_posts set closed_at = case when p_closed then now() end where id = p_job;
end;
$$;

create or replace function job_post_update(
  p_owner uuid, p_job uuid, p_title text, p_company text,
  p_description text, p_contact text
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
  if v_owner <> p_owner then raise exception 'not_owner'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 2 and 120
     or char_length(btrim(coalesce(p_company, ''))) not between 1 and 120
     or char_length(btrim(coalesce(p_description, ''))) not between 1 and 5000
     or char_length(coalesce(p_contact, '')) > 300 then
    raise exception 'invalid_input';
  end if;
  update job_posts
     set title = btrim(p_title), company = btrim(p_company),
         description = btrim(p_description),
         contact_info = nullif(btrim(coalesce(p_contact, '')), '')
   where id = p_job;
end;
$$;

revoke execute on function job_post_set_closed(uuid, uuid, boolean) from public;
revoke execute on function job_post_update(uuid, uuid, text, text, text, text) from public;
grant execute on function job_post_set_closed(uuid, uuid, boolean) to anon, authenticated;
grant execute on function job_post_update(uuid, uuid, text, text, text, text) to anon, authenticated;
