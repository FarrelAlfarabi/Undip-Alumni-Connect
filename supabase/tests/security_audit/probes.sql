-- Security audit probes (Stage 5). Runs ONLY on the throwaway local Postgres
-- started by run_audit.sh. Never point this at a live project.
--
-- Every probe asks: "as the anonymous API role (what the app and anyone with
-- the anon key is), does the weakness exist?" and records weak = true/false.
-- P* probes are weaknesses (true = the exploit works). C* probes are
-- controls that must stay false, so we know the harness can tell the
-- difference. All fixture people use example.com addresses; no real data.
\set ON_ERROR_STOP on
\o /dev/null

create schema audit;
create table audit.results (id text primary key, weak boolean not null, note text);

-- Runs a statement as anon; returns 'ok:<rows>' or 'err:<message>'.
create function audit.try(p_sql text) returns text language plpgsql as $$
declare n bigint;
begin
  set local role anon;
  begin
    execute p_sql;
    get diagnostics n = row_count;
    reset role;
    return 'ok:' || n;
  exception when others then
    reset role;
    return 'err:' || sqlerrm;
  end;
end $$;

-- Number of rows a query returns to anon; -1 if it errors.
create function audit.n(p_sql text) returns bigint language plpgsql as $$
declare n bigint;
begin
  set local role anon;
  begin
    execute 'select count(*) from (' || p_sql || ') q' into n;
    reset role;
    return n;
  exception when others then
    reset role;
    return -1;
  end;
end $$;

-- First value of a query as anon (null on error or no row).
create function audit.val(p_sql text) returns text language plpgsql as $$
declare v text;
begin
  set local role anon;
  begin
    execute p_sql into v;
    reset role;
    return v;
  exception when others then
    reset role;
    return null;
  end;
end $$;

create function audit.rec(p_id text, p_weak boolean, p_note text) returns void language sql as $$
  insert into audit.results values (p_id, coalesce(p_weak, false), p_note)
$$;

-- ---------------------------------------------------------------- fixtures ---
insert into alumni_profiles (id, nim, name, faculty, major, graduation_year, email, subscription_status, verification_status, current_employer) values
 ('aaaaaaaa-0000-4000-8000-000000000001','A001','Alice Example','Fakultas Ekonomika dan Bisnis','Manajemen',2020,'alice@example.com','subscribed','verified','Acme'),
 ('bbbbbbbb-0000-4000-8000-000000000002','B002','Bob Example','Fakultas Ekonomika dan Bisnis','Akuntansi',2021,'bob@example.com','free','verified','Beta'),
 ('cccccccc-0000-4000-8000-000000000003','C003','Audit Admin','Fakultas Ekonomika dan Bisnis','Manajemen',2019,'audit.admin@example.com','free','verified','Gamma');
insert into marketplace_admins (profile_id) values ('cccccccc-0000-4000-8000-000000000003');
-- When the passphrase migration is present, give the admin a passphrase the
-- way the owner would (owner-only helper). Absent before that migration.
do $$
begin
  if to_regprocedure('marketplace_set_admin_key(uuid,text)') is not null then
    perform marketplace_set_admin_key('cccccccc-0000-4000-8000-000000000003', 'audit-passphrase-1234');
  end if;
end $$;

insert into conversations (id, participant_one, participant_two) values
 ('dddddddd-0000-4000-8000-000000000001','aaaaaaaa-0000-4000-8000-000000000001','bbbbbbbb-0000-4000-8000-000000000002');
insert into messages (conversation_id, sender_id, body) values
 ('dddddddd-0000-4000-8000-000000000001','aaaaaaaa-0000-4000-8000-000000000001','PRIVATE: fixture message');
insert into job_posts (id, posted_by, title, company, industry, description, contact_info) values
 ('eeeeeeee-0000-4000-8000-000000000001','aaaaaaaa-0000-4000-8000-000000000001','Analyst','Acme','Finance','Fixture job','alice@example.com (fixture contact)');
insert into job_applications (job_post_id, applicant_id, full_name, email, phone, cover_note, cv_path) values
 ('eeeeeeee-0000-4000-8000-000000000001','bbbbbbbb-0000-4000-8000-000000000002','Bob Example','bob@example.com','0800-0000-0000','fixture note','eeeeeeee-0000-4000-8000-000000000001/1_cv.pdf');
insert into notifications (id, recipient_id, title, body) values
 ('ffffffff-0000-4000-8000-000000000001','aaaaaaaa-0000-4000-8000-000000000001','Fixture','Fixture body');
insert into email_log (recipient_email, subject, body) values ('alice@example.com','Fixture','Fixture body');
insert into city_chat_messages (city, sender_id, body) values ('Jakarta','aaaaaaaa-0000-4000-8000-000000000001','fixture city message');
insert into marketplace_listings (id, seller_id, title, description, price_idr, category, city, image_url, contact_info, status) values
 ('11111111-0000-4000-8000-000000000001','aaaaaaaa-0000-4000-8000-000000000001','Pending Item','Fixture',1000,'Other','Jakarta','https://img.example.com/a.jpg','wa 0800-0000-0001','pending'),
 ('11111111-0000-4000-8000-000000000002','aaaaaaaa-0000-4000-8000-000000000001','Approved Item','Fixture',2000,'Other','Jakarta','https://img.example.com/b.jpg','wa 0800-0000-0002','approved');
insert into storage.buckets (id, name, public) values ('cvs','cvs',true) on conflict (id) do nothing;
insert into storage.objects (bucket_id, name) values ('cvs','eeeeeeee-0000-4000-8000-000000000001/1_cv.pdf');
insert into storage.objects (bucket_id, name) values ('marketplace','aaaaaaaa-0000-4000-8000-000000000001/1.jpg');

-- ------------------------------------------------------------- A01 reads ---
select audit.rec('P01', audit.n('select * from messages') > 0, 'anon reads every private message');
select audit.rec('P02', audit.n('select * from conversations') > 0, 'anon reads every conversation (who talks to whom)');
select audit.rec('P03', audit.n('select email, phone, cover_note from job_applications') > 0, 'anon reads applicant email, phone and cover note');
select audit.rec('P04', audit.n('select email, nim from alumni_profiles') > 0, 'anon reads every alumnus email and NIM (email is the login)');
select audit.rec('P05', audit.n('select * from notifications') > 0, 'anon reads everyone''s notifications');
select audit.rec('P08', audit.n('select recipient_email, body from email_log') > 0, 'anon reads the simulated email log');
select audit.rec('P10', audit.n('select * from city_chat_messages') > 0, 'anon reads all city chats');
select audit.rec('P33', audit.val('select contact_info from job_posts limit 1') is not null, 'job contact info is readable without subscribing (paywall is client-side only)');
select audit.rec('P34', audit.val('select contact_info from marketplace_listings where status = ''approved'' limit 1') is not null, 'approved listing contact info readable by anyone with the anon key (documented demo gap)');

-- ------------------------------------------------ A01 writes (impersonation) ---
select audit.rec('P06', audit.try($q$insert into notifications (recipient_id, title, body) values ('aaaaaaaa-0000-4000-8000-000000000001','Forged','from anon')$q$) like 'ok%', 'anon inserts a notification for anyone');
select audit.rec('P07', audit.try($q$update notifications set title = 'Tampered', body = 'Tampered' where id = 'ffffffff-0000-4000-8000-000000000001'$q$) = 'ok:1', 'anon rewrites someone''s notification text');
select audit.rec('P09', audit.try($q$insert into email_log (recipient_email, subject, body) values ('alice@example.com','Forged','phish')$q$) like 'ok%', 'anon inserts a forged email-log row');
select audit.rec('P11', audit.try($q$insert into city_chat_messages (city, sender_id, body) values ('Jakarta','aaaaaaaa-0000-4000-8000-000000000001','said by anon')$q$) like 'ok%', 'anon posts in a city chat as another person');
select audit.rec('P12', audit.try($q$insert into messages (conversation_id, sender_id, body) values ('dddddddd-0000-4000-8000-000000000001','aaaaaaaa-0000-4000-8000-000000000001','said by anon')$q$) like 'ok%', 'anon sends a DM as another person into their conversation');
select audit.rec('P13', audit.try($q$insert into job_posts (posted_by, title, company, description) values ('aaaaaaaa-0000-4000-8000-000000000001','Fake job','X','posted by anon')$q$) like 'ok%', 'anon posts a job as another person');
select audit.rec('P14', audit.try($q$update alumni_profiles set subscription_status = 'subscribed' where email = 'bob@example.com'$q$) = 'ok:1', 'anon grants anyone a paid subscription');
select audit.rec('P15', audit.try($q$update alumni_profiles set current_employer = 'Defaced Ltd' where email = 'alice@example.com'$q$) = 'ok:1', 'anon edits another person''s employer');

-- --------------------------------------- marketplace: admin and seller ids ---
select audit.rec('P16', audit.val($q$select id::text from alumni_profiles where email = 'audit.admin@example.com'$q$) is not null, 'the admin''s profile id is readable by email lookup');
select audit.rec('P17', audit.val(format('select marketplace_is_admin(%L)', 'cccccccc-0000-4000-8000-000000000003')) = 'true', 'marketplace_is_admin(id) confirms an admin id');
select audit.rec('P18', audit.n(format('select * from marketplace_admin_pending(%L)', 'cccccccc-0000-4000-8000-000000000003')) > 0, 'anon reads the admin queue (pending listings with contact info) using only the admin id');
select audit.rec('P19', audit.try(format('select marketplace_review_listing(%L, %L, ''approved'')', 'cccccccc-0000-4000-8000-000000000003', '11111111-0000-4000-8000-000000000001')) like 'ok%', 'anon approves a listing as admin using only the admin id');
select audit.rec('P20', audit.n(format('select * from marketplace_my_listings(%L)', 'aaaaaaaa-0000-4000-8000-000000000001')) > 0, 'anon reads another seller''s listings (including pending/rejected) by id');
select audit.rec('P23', audit.try($q$insert into marketplace_reports (listing_id, reporter, reason) values ('11111111-0000-4000-8000-000000000002','bbbbbbbb-0000-4000-8000-000000000002','spam')$q$) like 'ok%'
  and audit.try($q$insert into marketplace_reports (listing_id, reporter, reason) values ('11111111-0000-4000-8000-000000000002','cccccccc-0000-4000-8000-000000000003','spam')$q$) like 'ok%', 'anon files reports under any reporter id (no limit per real person)');
select audit.rec('P21', audit.try(format('select marketplace_delete_listing(%L, %L)', 'aaaaaaaa-0000-4000-8000-000000000001', '11111111-0000-4000-8000-000000000002')) like 'ok%', 'anon deletes another seller''s listing by id');
-- ------------------------------------------- input limits and validation ---
select audit.rec('P24', audit.try(format($q$insert into messages (conversation_id, sender_id, body) values ('dddddddd-0000-4000-8000-000000000001','bbbbbbbb-0000-4000-8000-000000000002',%L)$q$, repeat('x', 1000000))) like 'ok%', 'a 1 MB message is accepted (no length limit)');
select audit.rec('P25', audit.try(format($q$insert into job_posts (posted_by, title, company, description) values ('bbbbbbbb-0000-4000-8000-000000000002','t','c',%L)$q$, repeat('x', 1000000))) like 'ok%', 'a 1 MB job description is accepted (no length limit)');
update alumni_profiles set subscription_status = 'subscribed' where email = 'bob@example.com';
select audit.rec('P27', audit.try($q$select marketplace_create_listing('bbbbbbbb-0000-4000-8000-000000000002','Odd Image','Fixture',1000,'Other','Jakarta','javascript:alert(1)',null,'wa 0800-0000-0003')$q$) like 'ok%', 'a listing image_url of javascript: is accepted');

-- ------------------------------------------------------------- storage ---
select audit.rec('P28', audit.n($q$select * from storage.objects where bucket_id = 'cvs'$q$) > 0, 'anon can list every CV path in the cvs bucket');
select audit.rec('P29', audit.try($q$insert into storage.objects (bucket_id, name) values ('cvs','anything/evil.html')$q$) like 'ok%', 'anon uploads any file type to the cvs bucket');
select audit.rec('P30', (select file_size_limit is null and allowed_mime_types is null from storage.buckets where id = 'cvs'), 'cvs bucket has no size limit and no type limit');
select audit.rec('P31', audit.n($q$select * from storage.objects where bucket_id = 'marketplace'$q$) > 0, 'anon can list every file in the marketplace bucket');

-- ------------------------------------------------------- A09 audit trail ---
-- A legitimate review (as the database owner, using whichever signature this
-- schema version has) must leave a reviewer behind.
insert into marketplace_listings (id, seller_id, title, description, price_idr, category, city, image_url, contact_info, status) values
 ('11111111-0000-4000-8000-000000000003','aaaaaaaa-0000-4000-8000-000000000001','Review Me','Fixture',3000,'Other','Jakarta','https://img.example.com/c.jpg','wa 0800-0000-0003','pending');
do $$
begin
  if to_regprocedure('marketplace_review_listing(uuid,uuid,text,text,text)') is not null then
    perform marketplace_review_listing('cccccccc-0000-4000-8000-000000000003', '11111111-0000-4000-8000-000000000003', 'approved', null, 'audit-passphrase-1234');
  else
    perform marketplace_review_listing('cccccccc-0000-4000-8000-000000000003', '11111111-0000-4000-8000-000000000003', 'approved');
  end if;
end $$;
select audit.rec('P36', coalesce((select to_jsonb(l)->>'reviewed_by' from marketplace_listings l where id = '11111111-0000-4000-8000-000000000003') is null, true), 'admin decisions record no reviewer');

-- ---------------------------------------------------------- controls (C*) ---
select audit.rec('C1', audit.try($q$delete from messages where id in (select id from messages limit 1)$q$) = 'ok:1', 'control: anon deletes a message (must be blocked)');
select audit.rec('C2', audit.try($q$insert into marketplace_listings (seller_id, title, description, price_idr, category, city, image_url, contact_info) values ('aaaaaaaa-0000-4000-8000-000000000001','abc','d',1,'Other','J','https://x.example/i.jpg','c')$q$) like 'ok%', 'control: anon inserts a listing directly (must be blocked)');
select audit.rec('C3', audit.try($q$select * from marketplace_admins$q$) like 'ok%', 'control: anon reads marketplace_admins (must be blocked)');
select audit.rec('C4', audit.try($q$select * from marketplace_reports$q$) like 'ok%', 'control: anon reads reports (must be blocked)');
select audit.rec('C5', audit.try($q$insert into alumni_profiles (nim, name, faculty, major, graduation_year, email) values ('Z9','Fake','F','M',2020,'fake@example.com')$q$) like 'ok%', 'control: anon inserts a fake profile (must be blocked)');
select audit.rec('C6', audit.n($q$select * from marketplace_listings where status = 'pending'$q$) > 0, 'control: anon reads pending listings directly (must be blocked)');

-- Positive control (only when passphrase-protected admin functions exist):
-- the real admin, with the right passphrase, still gets in as anon.
do $$
begin
  if to_regprocedure('marketplace_admin_pending(uuid,text)') is not null then
    perform audit.rec('C7', audit.n(format('select * from marketplace_admin_pending(%L, %L)', 'cccccccc-0000-4000-8000-000000000003', 'audit-passphrase-1234')) < 0, 'control: the admin with the right passphrase can use the queue (must work)');
  end if;
end $$;

\o
select 'PROBE|' || id || '|' || weak::text || '|' || note from audit.results order by id;
