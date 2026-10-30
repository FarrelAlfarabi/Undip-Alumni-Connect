-- Bio (max 200) and LinkedIn (https linkedin.com link only) on alumni_profiles.
\set ON_ERROR_STOP on
\o /dev/null
begin;

select jt.assert(
  (select count(*) = 2 from information_schema.columns
    where table_name = 'alumni_profiles' and column_name in ('bio', 'linkedin_url')),
  'both columns exist');

update alumni_profiles set bio = repeat('a', 200), linkedin_url = 'https://www.linkedin.com/in/demo'
  where email = 'ahmad.ramadhan@example.com';
select jt.assert(
  (select bio = repeat('a', 200) from alumni_profiles where email = 'ahmad.ramadhan@example.com'),
  '200 characters of bio are accepted');

do $$
begin
  begin
    update alumni_profiles set bio = repeat('a', 201) where email = 'ahmad.ramadhan@example.com';
    raise exception 'bio over 200 was accepted';
  exception when check_violation then null;
  end;
  begin
    update alumni_profiles set linkedin_url = 'https://evil.example.com/in/x'
      where email = 'ahmad.ramadhan@example.com';
    raise exception 'non linkedin link was accepted';
  exception when check_violation then null;
  end;
  begin
    update alumni_profiles set linkedin_url = 'javascript:alert(1)'
      where email = 'ahmad.ramadhan@example.com';
    raise exception 'javascript link was accepted';
  exception when check_violation then null;
  end;
end $$;

do $$
begin
  begin
    update alumni_profiles set bio = '   ' where email = 'ahmad.ramadhan@example.com';
    raise exception 'blank bio was accepted';
  exception when check_violation then null;
  end;
end $$;

update alumni_profiles set deleted_at = now() where email = 'ahmad.ramadhan@example.com';
select jt.assert(
  (select bio is null and linkedin_url is null from alumni_profiles
    where email = 'ahmad.ramadhan@example.com'),
  'deleting the account clears bio and linkedin');

select jt.assert(
  has_column_privilege('anon', 'alumni_profiles', 'bio', 'select')
  and has_column_privilege('authenticated', 'alumni_profiles', 'linkedin_url', 'select'),
  'select granted like the other columns');

rollback;
\o
\echo profile bio and linkedin checks passed
