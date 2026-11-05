-- Poster notice for a job an admin takes down now says "ditangguhkan",
-- matching the "Tangguhkan" button in admin Jobs.
create or replace function job_posts_notify_hidden()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.hidden_at is null and new.hidden_at is not null then
    perform notify_create(new.posted_by, null, 'content_hidden', 'Ditangguhkan oleh admin',
      'Lowongan "' || new.title || '" ditangguhkan.' || coalesce(' Alasan: ' || new.hidden_reason, ''),
      'job', new.id, 'hidden:job:' || new.id::text || ':' || notify_stamp());
  end if;
  return new;
end;
$$;
revoke execute on function job_posts_notify_hidden() from public, anon, authenticated;
