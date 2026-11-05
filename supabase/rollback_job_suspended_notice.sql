-- Undo 20261105250000_job_suspended_notice.sql. Safe to run twice.
-- Notices already written stay as they are.
create or replace function job_posts_notify_hidden()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.hidden_at is null and new.hidden_at is not null then
    perform notify_create(new.posted_by, null, 'content_hidden', 'Disembunyikan oleh admin',
      'Lowongan "' || new.title || '" disembunyikan.' || coalesce(' Alasan: ' || new.hidden_reason, ''),
      'job', new.id, 'hidden:job:' || new.id::text || ':' || notify_stamp());
  end if;
  return new;
end;
$$;
revoke execute on function job_posts_notify_hidden() from public, anon, authenticated;
