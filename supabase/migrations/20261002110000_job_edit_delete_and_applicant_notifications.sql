-- ============================================================================
-- Posters can edit and delete their own jobs, applicants are told when their
-- application status changes, and "IT" is folded into "Technology" (2 Oct 2026).
--
-- Edit and delete go through functions that check posted_by = the caller's
-- profile id, instead of opening update/delete policies on job_posts to
-- everyone. Same demo caveat as the rest of this schema: the id is sent by
-- the app and there is no real login, so this stops casual mistakes and
-- cross-user edits through the app, not a determined attacker who knows a
-- poster's id (SECURITY_AUDIT.md SA-05).
--
-- Deleting a job also removes its applications, notifications and email-log
-- rows (their foreign keys have no cascade).
-- ============================================================================

create or replace function update_job_post(
  p_job uuid,
  p_poster uuid,
  p_title text,
  p_company text,
  p_industry text,
  p_description text,
  p_contact_info text,
  p_notify_on_apply boolean,
  p_require_cv boolean,
  p_require_linkedin boolean,
  p_require_portfolio boolean,
  p_require_cover_note boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update job_posts set
    title = p_title,
    company = p_company,
    industry = p_industry,
    description = p_description,
    contact_info = p_contact_info,
    notify_on_apply = p_notify_on_apply,
    require_cv = p_require_cv,
    require_linkedin = p_require_linkedin,
    require_portfolio = p_require_portfolio,
    require_cover_note = p_require_cover_note
  where id = p_job and posted_by = p_poster;
  if not found then raise exception 'not_owner'; end if;
end;
$$;

create or replace function delete_job_post(p_job uuid, p_poster uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from job_posts where id = p_job and posted_by = p_poster) then
    raise exception 'not_owner';
  end if;
  delete from notifications where job_post_id = p_job;
  delete from email_log where job_post_id = p_job;
  delete from job_applications where job_post_id = p_job;
  delete from job_posts where id = p_job;
end;
$$;

revoke execute on function update_job_post(uuid, uuid, text, text, text, text, text, boolean, boolean, boolean, boolean, boolean) from public;
revoke execute on function delete_job_post(uuid, uuid) from public;
grant execute on function update_job_post(uuid, uuid, text, text, text, text, text, boolean, boolean, boolean, boolean, boolean) to anon, authenticated;
grant execute on function delete_job_post(uuid, uuid) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- Tell the applicant when the poster changes their application's status.
-- Same pattern as notify_poster_on_application(): a trigger, so it can't be
-- skipped by a client bug.
-- ----------------------------------------------------------------------------
create or replace function notify_applicant_on_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_label text;
begin
  if new.status is distinct from old.status then
    select title into v_title from job_posts where id = new.job_post_id;
    v_label := case new.status
      when 'reviewed' then 'under review'
      when 'accepted' then 'accepted'
      when 'rejected' then 'not selected'
      else 'pending'
    end;
    insert into notifications (recipient_id, job_post_id, title, body)
    values (
      new.applicant_id,
      new.job_post_id,
      'Application update: ' || coalesce(v_title, 'a job'),
      'Your application for "' || coalesce(v_title, 'a job') || '" is now ' || v_label || '.'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists job_applications_notify_applicant on job_applications;
create trigger job_applications_notify_applicant
  after update of status on job_applications
  for each row execute function notify_applicant_on_status_change();

revoke execute on function notify_applicant_on_status_change() from public, anon, authenticated;

-- One name for one industry, so the job board filter has no near-duplicates.
update job_posts set industry = 'Technology' where industry = 'IT';
