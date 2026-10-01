-- ============================================================================
-- Security hardening (audit stage 5, Part B). Fixes what can be fixed WITHOUT
-- real Supabase Auth. It does NOT make the database safe for real alumni
-- data: reads of messages, applications, emails and profiles, and every
-- "act as any user" write, still need auth.uid() (see SECURITY_AUDIT.md).
--
-- NOT applied to any live project by whoever wrote it. Apply first on a
-- separate project or a Supabase branch database, then look at photo and CV
-- links in the app before touching the shared project. Rollback:
-- supabase/rollback_security_hardening.sql
--
-- Fixes (finding ids from SECURITY_AUDIT.md):
--   SA-10  notifications and email_log: no direct insert; notifications can
--          only have `read_at` changed
--   SA-11  cvs bucket: no listing, 5 MB, pdf/doc/docx only
--   SA-20  marketplace bucket: no listing
--   SA-15  length limits on user text
--   SA-16  marketplace image_url must be https
--   SA-18  admin decisions record reviewer and time
--
-- Idempotent: safe to re-run.
-- ============================================================================

-- ---------------------------------------------------------------- SA-10 ---
-- notifications and email_log rows are written by the SECURITY DEFINER
-- trigger notify_poster_on_application(), which runs as the table owner, so
-- the API roles need no insert right at all.
drop policy if exists "notifications_insert" on notifications;
drop policy if exists "email_log_insert" on email_log;
revoke insert on notifications from anon, authenticated;
revoke insert on email_log from anon, authenticated;

-- The app only ever marks a notification read. Allow exactly that column.
revoke update on notifications from anon, authenticated;
grant update (read_at) on notifications to anon, authenticated;

-- ------------------------------------------------------- SA-11 and SA-20 ---
-- Public buckets serve files by URL without any policy, so dropping the
-- SELECT policies only removes the ability to LIST every path through the
-- API. The app never lists; it stores a public URL.
drop policy if exists "cvs_public_read" on storage.objects;
drop policy if exists "marketplace_public_read" on storage.objects;

update storage.buckets
set file_size_limit = 5242880,  -- 5 MB
    allowed_mime_types = array[
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ]
where id = 'cvs';

drop policy if exists "cvs_public_upload" on storage.objects;
create policy "cvs_public_upload" on storage.objects
  for insert with check (
    bucket_id = 'cvs'
    and lower(storage.extension(name)) in ('pdf', 'doc', 'docx')
  );

-- ---------------------------------------------------------------- SA-15 ---
-- NOT VALID: enforced for every new or changed row, existing rows are not
-- re-checked (so a re-run on a database with older data cannot fail).
do $$
declare
  c record;
begin
  for c in select * from (values
    ('messages',            'messages_body_len',            'char_length(body) <= 4000'),
    ('city_chat_messages',  'city_chat_body_len',           'char_length(body) <= 2000'),
    ('job_posts',           'job_posts_title_len',          'char_length(title) <= 200'),
    ('job_posts',           'job_posts_company_len',        'char_length(company) <= 200'),
    ('job_posts',           'job_posts_industry_len',       'industry is null or char_length(industry) <= 100'),
    ('job_posts',           'job_posts_description_len',    'char_length(description) <= 10000'),
    ('job_posts',           'job_posts_contact_len',        'contact_info is null or char_length(contact_info) <= 500'),
    ('job_applications',    'job_applications_name_len',    'char_length(full_name) <= 200'),
    ('job_applications',    'job_applications_email_len',   'char_length(email) <= 254'),
    ('job_applications',    'job_applications_phone_len',   'phone is null or char_length(phone) <= 50'),
    ('job_applications',    'job_applications_linkedin_len','linkedin_url is null or char_length(linkedin_url) <= 500'),
    ('job_applications',    'job_applications_portfolio_len','portfolio_url is null or char_length(portfolio_url) <= 500'),
    ('job_applications',    'job_applications_note_len',    'cover_note is null or char_length(cover_note) <= 5000'),
    ('job_applications',    'job_applications_cv_len',      'cv_path is null or char_length(cv_path) <= 500'),
    ('marketplace_listings','marketplace_listings_contact_len','contact_info is null or char_length(contact_info) <= 300'),
    ('marketplace_listings','marketplace_listings_shop_len','shop_url is null or char_length(shop_url) <= 500')
  ) as t(tbl, name, expr)
  loop
    if not exists (select 1 from pg_constraint where conname = c.name) then
      execute format('alter table %I add constraint %I check (%s) not valid', c.tbl, c.name, c.expr);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------- SA-16 ---
-- Listing photos must be https links (no javascript:, data:, http:). Any
-- https host is still allowed because the seed uses an image service; the
-- app itself only ever stores the marketplace bucket's own URL.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'marketplace_listings_image_https') then
    alter table marketplace_listings
      add constraint marketplace_listings_image_https
      check (image_url ~ '^https://[^[:space:]]+$' and char_length(image_url) <= 500) not valid;
  end if;
end $$;

-- ---------------------------------------------------------------- SA-18 ---
alter table marketplace_listings add column if not exists reviewed_by uuid references alumni_profiles (id);
alter table marketplace_listings add column if not exists reviewed_at timestamptz;

create or replace function marketplace_review_listing(
  p_admin uuid,
  p_listing uuid,
  p_decision text,
  p_reason text default null
)
returns marketplace_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v marketplace_listings;
begin
  if not marketplace_is_admin(p_admin) then raise exception 'not_admin'; end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception 'invalid_decision';
  end if;
  if p_decision = 'rejected' and nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'reason_required';
  end if;

  select * into v from marketplace_listings where id = p_listing for update;
  if not found then raise exception 'not_found'; end if;
  if v.status <> 'pending' then raise exception 'invalid_state'; end if;

  update marketplace_listings set
    status = p_decision,
    rejected_reason = case when p_decision = 'rejected' then btrim(p_reason) else null end,
    approved_at = case when p_decision = 'approved' then now() else null end,
    reviewed_by = p_admin,
    reviewed_at = now(),
    updated_at = now()
  where id = p_listing
  returning * into v;

  return v;
end;
$$;

revoke execute on function marketplace_review_listing(uuid, uuid, text, text) from public;
grant execute on function marketplace_review_listing(uuid, uuid, text, text) to anon, authenticated;
