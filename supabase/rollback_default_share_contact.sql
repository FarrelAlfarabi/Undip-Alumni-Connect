drop trigger if exists profile_share_defaults_cleanup_trigger on alumni_profiles;
drop function if exists profile_share_defaults_cleanup();
drop function if exists contact_default_get(uuid);
drop function if exists contact_default_set(uuid, text);
drop table if exists profile_share_defaults;
