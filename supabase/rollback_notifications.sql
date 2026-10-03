-- Undo 20261003150000_notifications.sql. Safe to run twice.
-- Removes the new triggers and puts the old job application trigger function
-- back. The notifications table and its rows are kept; only the new columns
-- (type, target_type, target_id, actor_id, event_key) are dropped.
drop trigger if exists contact_requests_notify_insert on contact_requests;
drop trigger if exists contact_requests_notify_update on contact_requests;
drop function if exists contact_requests_notify();
drop trigger if exists businesses_notify_insert on businesses;
drop trigger if exists businesses_notify_update on businesses;
drop function if exists businesses_notify();
drop trigger if exists job_posts_notify_hidden_trigger on job_posts;
drop function if exists job_posts_notify_hidden();
drop trigger if exists marketplace_listings_notify_hidden_trigger on marketplace_listings;
drop function if exists marketplace_listings_notify_hidden();
drop trigger if exists content_reports_notify_trigger on content_reports;
drop function if exists content_reports_notify();
drop trigger if exists marketplace_reports_notify_trigger on marketplace_reports;
drop function if exists marketplace_reports_notify();

create or replace function notify_poster_on_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job job_posts%rowtype;
  v_poster_email text;
  v_applicant_name text;
begin
  select * into v_job from job_posts where id = new.job_post_id;
  if v_job.id is null or v_job.notify_on_apply is false then
    return new;
  end if;

  v_applicant_name := coalesce(nullif(new.full_name, ''), 'Someone');

  insert into notifications (recipient_id, job_post_id, title, body)
  values (
    v_job.posted_by,
    v_job.id,
    'New application: ' || v_job.title,
    v_applicant_name || ' applied to your "' || v_job.title || '" posting.'
  );

  select email into v_poster_email from alumni_profiles where id = v_job.posted_by;

  if v_poster_email is not null then
    insert into email_log (recipient_email, subject, body, job_post_id)
    values (
      v_poster_email,
      'New application for ' || v_job.title,
      v_applicant_name || ' just applied to your job posting "' || v_job.title ||
        '" at ' || v_job.company || '. Open UNDIP Alumni Connect to review the application.',
      v_job.id
    );
  end if;

  return new;
end;
$$;
revoke execute on function notify_poster_on_application() from public, anon, authenticated;

drop function if exists notify_stamp();
drop function if exists notify_admins(uuid, text, text, text, text, uuid, text);
drop function if exists notify_create(uuid, uuid, text, text, text, text, uuid, text);
drop index if exists notifications_event_key_uq;
alter table notifications drop column if exists event_key;
alter table notifications drop column if exists actor_id;
alter table notifications drop column if exists target_id;
alter table notifications drop column if exists target_type;
alter table notifications drop column if exists type;
