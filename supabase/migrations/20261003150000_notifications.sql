-- ============================================================================
-- In-app notifications from the database (closed beta, Stage 6E).
--
-- The app NEVER inserts notifications. Only triggers (and the internal
-- function notify_create) do. Anon inserts, deletes and updates other than
-- read_at are refused. NO PUSH: push needs a Firebase project and keys; that
-- is a next step.
--
-- Reading is still NOT private: with no real login, anyone with the anon key
-- can read every notification row. Only the recipient filter in the app
-- narrows the list.
--
-- Events (one row per event, no duplicates):
--   contact request received            -> the target
--   contact request accepted            -> the requester (a rejection: none)
--   business approved / rejected (with reason) / suspended / restored
--                                       -> the owner
--   job, product or business hidden by an admin (with reason) -> the owner
--   new report, new pending business    -> every admin
--   someone applied to my job           -> the poster (existing trigger, now
--                                          typed; still honours notify_on_apply)
-- Never: for your own action, or from a person the receiver blocked.
--
-- Not applied to any live project by whoever wrote it. Idempotent.
-- Rollback: supabase/rollback_notifications.sql
-- ============================================================================

alter table notifications add column if not exists type text;
alter table notifications add column if not exists target_type text;
alter table notifications add column if not exists target_id uuid;
alter table notifications add column if not exists actor_id uuid references alumni_profiles (id);
alter table notifications add column if not exists event_key text;
create unique index if not exists notifications_event_key_uq on notifications (event_key) where event_key is not null;

-- The app can only mark a notification as read. (Same as the hardening
-- migration; repeated here so this migration stands on its own.)
drop policy if exists "notifications_insert" on notifications;
revoke insert, delete, truncate on notifications from anon, authenticated;
revoke update on notifications from anon, authenticated;
grant update (read_at) on notifications to anon, authenticated;

-- Distinguishes two separate events on the same row (approve, reject, approve
-- again). A trigger firing twice for ONE change is stopped by the status
-- checks, and by event_key for everything else.
create or replace function notify_stamp()
returns text
language sql
volatile
as $$ select (extract(epoch from clock_timestamp()) * 1000000)::bigint::text $$;
revoke execute on function notify_stamp() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The one place that creates a notification. Internal: no API role can run it.
-- Returns true when a row was created.
-- ---------------------------------------------------------------------------
create or replace function notify_create(
  p_recipient uuid,
  p_actor uuid,
  p_type text,
  p_title text,
  p_body text,
  p_target_type text,
  p_target_id uuid,
  p_key text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if p_recipient is null then return false; end if;
  -- Not for your own action.
  if p_actor is not null and p_actor = p_recipient then return false; end if;
  -- Not from a person the receiver blocked.
  if p_actor is not null and exists (
    select 1 from user_blocks where blocker_id = p_recipient and blocked_id = p_actor
  ) then
    return false;
  end if;

  insert into notifications
    (recipient_id, job_post_id, title, body, type, target_type, target_id, actor_id, event_key)
  values
    (p_recipient, case when p_target_type = 'job' then p_target_id end,
     left(p_title, 200), left(p_body, 500), p_type, p_target_type, p_target_id, p_actor, p_key)
  on conflict (event_key) where event_key is not null do nothing;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;
revoke execute on function notify_create(uuid, uuid, text, text, text, text, uuid, text) from public, anon, authenticated;

create or replace function notify_admins(
  p_actor uuid,
  p_type text,
  p_title text,
  p_body text,
  p_target_type text,
  p_target_id uuid,
  p_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  a record;
begin
  for a in select profile_id from app_admins loop
    perform notify_create(a.profile_id, p_actor, p_type, p_title, p_body, p_target_type, p_target_id,
                          p_key || ':' || a.profile_id::text);
  end loop;
end;
$$;
revoke execute on function notify_admins(uuid, text, text, text, text, uuid, text) from public, anon, authenticated;

-- ------------------------------------------------------- contact requests ---
create or replace function contact_requests_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform notify_create(
      new.target_id, new.requester_id, 'contact_request_received',
      'New request to contact',
      coalesce((select name from alumni_profiles where id = new.requester_id), 'Someone') || ' would like to contact you.',
      'contact_request', new.id, 'cr_received:' || new.id::text);
  elsif old.status = 'pending' and new.status = 'accepted' then
    perform notify_create(
      new.requester_id, new.target_id, 'contact_request_accepted',
      'Request accepted',
      coalesce((select name from alumni_profiles where id = new.target_id), 'Someone')
        || ' accepted your request. Open Requests to see what they shared.',
      'contact_request', new.id, 'cr_accepted:' || new.id::text);
  end if;
  return new;
end;
$$;
revoke execute on function contact_requests_notify() from public, anon, authenticated;

drop trigger if exists contact_requests_notify_insert on contact_requests;
create trigger contact_requests_notify_insert
  after insert on contact_requests
  for each row execute function contact_requests_notify();
drop trigger if exists contact_requests_notify_update on contact_requests;
create trigger contact_requests_notify_update
  after update of status on contact_requests
  for each row execute function contact_requests_notify();

-- -------------------------------------------------------------- businesses ---
create or replace function businesses_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tx text := notify_stamp();
  v_why text;
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      perform notify_admins(new.owner_id, 'business_pending', 'New business to review',
        '"' || new.name || '" is waiting for review.', 'business', new.id,
        'biz_pending:' || new.id::text || ':' || v_tx);
    end if;
    return new;
  end if;

  if old.status = 'rejected' and new.status = 'pending' then
    perform notify_admins(new.owner_id, 'business_pending', 'Business sent again',
      '"' || new.name || '" was fixed and is waiting for review.', 'business', new.id,
      'biz_pending:' || new.id::text || ':' || v_tx);
  end if;

  if new.status is distinct from old.status then
    v_why := nullif(btrim(coalesce(new.rejection_reason, '')), '');
    if new.status = 'approved' and old.status in ('pending', 'rejected') then
      perform notify_create(new.owner_id, new.reviewed_by, 'business_approved', 'Business approved',
        '"' || new.name || '" is approved. You can add products now.', 'business', new.id,
        'biz_approved:' || new.id::text || ':' || v_tx);
    elsif new.status = 'rejected' then
      perform notify_create(new.owner_id, new.reviewed_by, 'business_rejected', 'Business not approved',
        '"' || new.name || '" was not approved.' || coalesce(' Reason: ' || v_why, ''), 'business', new.id,
        'biz_rejected:' || new.id::text || ':' || v_tx);
    elsif new.status = 'suspended' then
      perform notify_create(new.owner_id, new.reviewed_by, 'business_suspended', 'Business suspended',
        '"' || new.name || '" is suspended.' || coalesce(' Reason: ' || v_why, ''), 'business', new.id,
        'biz_suspended:' || new.id::text || ':' || v_tx);
    elsif new.status = 'approved' and old.status = 'suspended' then
      perform notify_create(new.owner_id, new.reviewed_by, 'business_restored', 'Business restored',
        '"' || new.name || '" is active again.', 'business', new.id,
        'biz_restored:' || new.id::text || ':' || v_tx);
    end if;
  end if;

  if old.hidden_at is null and new.hidden_at is not null then
    perform notify_create(new.owner_id, null, 'content_hidden', 'Hidden by an admin',
      'Your business "' || new.name || '" was hidden.' || coalesce(' Reason: ' || new.hidden_reason, ''),
      'business', new.id, 'hidden:business:' || new.id::text || ':' || v_tx);
  end if;
  return new;
end;
$$;
revoke execute on function businesses_notify() from public, anon, authenticated;

drop trigger if exists businesses_notify_insert on businesses;
create trigger businesses_notify_insert
  after insert on businesses
  for each row execute function businesses_notify();
drop trigger if exists businesses_notify_update on businesses;
create trigger businesses_notify_update
  after update on businesses
  for each row execute function businesses_notify();

-- ------------------------------------------------- hidden jobs and products ---
create or replace function job_posts_notify_hidden()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.hidden_at is null and new.hidden_at is not null then
    perform notify_create(new.posted_by, null, 'content_hidden', 'Hidden by an admin',
      'Your job "' || new.title || '" was hidden.' || coalesce(' Reason: ' || new.hidden_reason, ''),
      'job', new.id, 'hidden:job:' || new.id::text || ':' || notify_stamp());
  end if;
  return new;
end;
$$;
revoke execute on function job_posts_notify_hidden() from public, anon, authenticated;
drop trigger if exists job_posts_notify_hidden_trigger on job_posts;
create trigger job_posts_notify_hidden_trigger
  after update of hidden_at on job_posts
  for each row execute function job_posts_notify_hidden();

create or replace function marketplace_listings_notify_hidden()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.hidden_at is null and new.hidden_at is not null then
    perform notify_create(new.seller_id, null, 'content_hidden', 'Hidden by an admin',
      'Your product "' || new.title || '" was hidden.' || coalesce(' Reason: ' || new.hidden_reason, ''),
      'product', new.id, 'hidden:product:' || new.id::text || ':' || notify_stamp());
  end if;
  return new;
end;
$$;
revoke execute on function marketplace_listings_notify_hidden() from public, anon, authenticated;
drop trigger if exists marketplace_listings_notify_hidden_trigger on marketplace_listings;
create trigger marketplace_listings_notify_hidden_trigger
  after update of hidden_at on marketplace_listings
  for each row execute function marketplace_listings_notify_hidden();

-- ------------------------------------------------------------ new reports ---
create or replace function content_reports_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform notify_admins(new.reporter_id, 'report_new', 'New report',
    'A ' || replace(new.target_type, '_', ' ') || ' was reported.', new.target_type, new.target_id,
    'report:' || new.id::text);
  return new;
end;
$$;
revoke execute on function content_reports_notify() from public, anon, authenticated;
drop trigger if exists content_reports_notify_trigger on content_reports;
create trigger content_reports_notify_trigger
  after insert on content_reports
  for each row execute function content_reports_notify();

create or replace function marketplace_reports_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform notify_admins(new.reporter, 'report_new', 'New report',
    'A product was reported.', 'product', new.listing_id, 'mreport:' || new.id::text);
  return new;
end;
$$;
revoke execute on function marketplace_reports_notify() from public, anon, authenticated;
drop trigger if exists marketplace_reports_notify_trigger on marketplace_reports;
create trigger marketplace_reports_notify_trigger
  after insert on marketplace_reports
  for each row execute function marketplace_reports_notify();

-- --------------------------------------------------- job applications (old) ---
-- Same behaviour as before (a notification and a simulated email when the
-- poster left notify_on_apply on), but typed, deduplicated, and silent for
-- the poster's own application or an applicant the poster blocked.
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
  v_created boolean;
begin
  select * into v_job from job_posts where id = new.job_post_id;
  if v_job.id is null or v_job.notify_on_apply is false then
    return new;
  end if;

  v_applicant_name := coalesce(nullif(new.full_name, ''), 'Someone');

  v_created := notify_create(
    v_job.posted_by, new.applicant_id, 'job_application',
    'New application: ' || v_job.title,
    v_applicant_name || ' applied to your "' || v_job.title || '" posting.',
    'job', v_job.id, 'job_app:' || new.id::text);

  if v_created then
    select email into v_poster_email from alumni_profiles where id = v_job.posted_by;
    if v_poster_email is not null then
      insert into email_log (recipient_email, subject, body, job_post_id)
      values (
        v_poster_email,
        'New application for ' || v_job.title,
        v_applicant_name || ' just applied to your job posting "' || v_job.title ||
          '" at ' || v_job.company || '. Open Lingkaran to review the application.',
        v_job.id
      );
    end if;
  end if;

  return new;
end;
$$;
revoke execute on function notify_poster_on_application() from public, anon, authenticated;
