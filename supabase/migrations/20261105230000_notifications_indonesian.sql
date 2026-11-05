-- Notification texts written by the database are now in Indonesian.
-- Also: the owner gets "Permintaan diterima" when a business is sent for review.
-- Only function bodies change. No table, trigger or grant changes.

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
      'Permintaan kontak baru',
      coalesce((select name from alumni_profiles where id = new.requester_id), 'Seseorang') || ' ingin menghubungi kamu.',
      'contact_request', new.id, 'cr_received:' || new.id::text);
  elsif old.status = 'pending' and new.status = 'accepted' then
    perform notify_create(
      new.requester_id, new.target_id, 'contact_request_accepted',
      'Permintaan diterima',
      coalesce((select name from alumni_profiles where id = new.target_id), 'Seseorang')
        || ' menerima permintaanmu. Buka Requests untuk melihat kontak yang dibagikan.',
      'contact_request', new.id, 'cr_accepted:' || new.id::text);
  end if;
  return new;
end;
$$;
revoke execute on function contact_requests_notify() from public, anon, authenticated;

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
      perform notify_admins(new.owner_id, 'business_pending', 'Bisnis baru perlu ditinjau',
        '"' || new.name || '" menunggu peninjauan.', 'business', new.id,
        'biz_pending:' || new.id::text || ':' || v_tx);
      perform notify_create(new.owner_id, null, 'business_received', 'Permintaan diterima',
        '"' || new.name || '" menunggu persetujuan admin.', 'business', new.id,
        'biz_received:' || new.id::text);
    end if;
    return new;
  end if;

  if old.status = 'rejected' and new.status = 'pending' then
    perform notify_admins(new.owner_id, 'business_pending', 'Bisnis dikirim ulang',
      '"' || new.name || '" sudah diperbaiki dan menunggu peninjauan.', 'business', new.id,
      'biz_pending:' || new.id::text || ':' || v_tx);
  end if;

  if new.status is distinct from old.status then
    v_why := nullif(btrim(coalesce(new.rejection_reason, '')), '');
    if new.status = 'approved' and old.status in ('pending', 'rejected') then
      perform notify_create(new.owner_id, new.reviewed_by, 'business_approved', 'Bisnis disetujui',
        '"' || new.name || '" disetujui. Sekarang kamu bisa menambah produk.', 'business', new.id,
        'biz_approved:' || new.id::text || ':' || v_tx);
    elsif new.status = 'rejected' then
      perform notify_create(new.owner_id, new.reviewed_by, 'business_rejected', 'Bisnis belum disetujui',
        '"' || new.name || '" belum disetujui.' || coalesce(' Alasan: ' || v_why, ''), 'business', new.id,
        'biz_rejected:' || new.id::text || ':' || v_tx);
    elsif new.status = 'suspended' then
      perform notify_create(new.owner_id, new.reviewed_by, 'business_suspended', 'Bisnis ditangguhkan',
        '"' || new.name || '" ditangguhkan.' || coalesce(' Alasan: ' || v_why, ''), 'business', new.id,
        'biz_suspended:' || new.id::text || ':' || v_tx);
    elsif new.status = 'approved' and old.status = 'suspended' then
      perform notify_create(new.owner_id, new.reviewed_by, 'business_restored', 'Bisnis aktif kembali',
        '"' || new.name || '" aktif kembali.', 'business', new.id,
        'biz_restored:' || new.id::text || ':' || v_tx);
    end if;
  end if;

  if old.hidden_at is null and new.hidden_at is not null then
    perform notify_create(new.owner_id, null, 'content_hidden', 'Disembunyikan oleh admin',
      'Bisnis "' || new.name || '" disembunyikan.' || coalesce(' Alasan: ' || new.hidden_reason, ''),
      'business', new.id, 'hidden:business:' || new.id::text || ':' || v_tx);
  end if;
  return new;
end;
$$;
revoke execute on function businesses_notify() from public, anon, authenticated;

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

create or replace function marketplace_listings_notify_hidden()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.hidden_at is null and new.hidden_at is not null then
    perform notify_create(new.seller_id, null, 'content_hidden', 'Disembunyikan oleh admin',
      'Produk "' || new.title || '" disembunyikan.' || coalesce(' Alasan: ' || new.hidden_reason, ''),
      'product', new.id, 'hidden:product:' || new.id::text || ':' || notify_stamp());
  end if;
  return new;
end;
$$;
revoke execute on function marketplace_listings_notify_hidden() from public, anon, authenticated;

create or replace function content_reports_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform notify_admins(new.reporter_id, 'report_new', 'Laporan baru',
    'Ada laporan untuk ' || case new.target_type
      when 'business' then 'bisnis'
      when 'job' then 'lowongan'
      when 'product' then 'produk'
      when 'profile' then 'profil'
      when 'contact_request' then 'permintaan kontak'
      else replace(new.target_type, '_', ' ') end || '.',
    new.target_type, new.target_id, 'report:' || new.id::text);
  return new;
end;
$$;
revoke execute on function content_reports_notify() from public, anon, authenticated;

create or replace function marketplace_reports_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform notify_admins(new.reporter, 'report_new', 'Laporan baru',
    'Ada laporan untuk produk.', 'product', new.listing_id, 'mreport:' || new.id::text);
  return new;
end;
$$;
revoke execute on function marketplace_reports_notify() from public, anon, authenticated;

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

  v_applicant_name := coalesce(nullif(new.full_name, ''), 'Seseorang');

  v_created := notify_create(
    v_job.posted_by, new.applicant_id, 'job_application',
    'Lamaran baru: ' || v_job.title,
    v_applicant_name || ' melamar lowongan "' || v_job.title || '" milikmu.',
    'job', v_job.id, 'job_app:' || new.id::text);

  if v_created then
    select email into v_poster_email from alumni_profiles where id = v_job.posted_by;
    if v_poster_email is not null then
      insert into email_log (recipient_email, subject, body, job_post_id)
      values (
        v_poster_email,
        'Lamaran baru untuk ' || v_job.title,
        v_applicant_name || ' baru saja melamar lowongan "' || v_job.title ||
          '" di ' || v_job.company || '. Buka Lingkaran untuk melihat lamaran.',
        v_job.id
      );
    end if;
  end if;

  return new;
end;
$$;
revoke execute on function notify_poster_on_application() from public, anon, authenticated;
