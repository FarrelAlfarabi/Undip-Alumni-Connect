-- Photos and CVs of deleted content are queued for removal from storage.
-- Before: only deleting an account queued files. A deleted business, product
-- or job post left its photo behind. Now a trigger on each table queues the
-- file whenever a row is deleted, by any path (the app, the dashboard, a
-- cascade). Farrel removes queued files from the dashboard (storage_cleanup_queue,
-- done_at null) the same way as for account deletion.
-- Idempotent. Rollback: supabase/rollback_storage_cleanup_triggers.sql

create or replace function storage_cleanup_enqueue(p_bucket text, p_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_path text;
begin
  if p_url is null or p_url = '' then return; end if;
  v_path := substring(p_url from '/object/public/' || p_bucket || '/([^?#]+)');
  if v_path is null then return; end if;
  if not exists (
    select 1 from storage_cleanup_queue q
     where q.bucket = p_bucket and q.path = v_path and q.done_at is null
  ) then
    insert into storage_cleanup_queue (bucket, path) values (p_bucket, v_path);
  end if;
end;
$$;
revoke execute on function storage_cleanup_enqueue(text, text) from public, anon, authenticated;

create or replace function storage_cleanup_on_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'marketplace_listings' then
    perform storage_cleanup_enqueue('marketplace', old.image_url);
  elsif tg_table_name = 'businesses' then
    perform storage_cleanup_enqueue('business-photos', old.photo_url);
  elsif tg_table_name = 'job_posts' then
    perform storage_cleanup_enqueue('job-photos', old.image_url);
  elsif tg_table_name = 'job_applications' then
    if old.cv_path is not null and old.cv_path <> '' and not exists (
      select 1 from storage_cleanup_queue q
       where q.bucket = 'cvs' and q.path = old.cv_path and q.done_at is null
    ) then
      insert into storage_cleanup_queue (bucket, path) values ('cvs', old.cv_path);
    end if;
  end if;
  return old;
end;
$$;
revoke execute on function storage_cleanup_on_delete() from public, anon, authenticated;

drop trigger if exists marketplace_listings_storage_cleanup on marketplace_listings;
create trigger marketplace_listings_storage_cleanup
  before delete on marketplace_listings
  for each row execute function storage_cleanup_on_delete();

drop trigger if exists businesses_storage_cleanup on businesses;
create trigger businesses_storage_cleanup
  before delete on businesses
  for each row execute function storage_cleanup_on_delete();

drop trigger if exists job_posts_storage_cleanup on job_posts;
create trigger job_posts_storage_cleanup
  before delete on job_posts
  for each row execute function storage_cleanup_on_delete();

drop trigger if exists job_applications_storage_cleanup on job_applications;
create trigger job_applications_storage_cleanup
  before delete on job_applications
  for each row execute function storage_cleanup_on_delete();
