-- Rolls back 20261103150100: deleting an account no longer removes the Auth
-- user. Auth users that were already deleted are NOT restored. Idempotent.
drop trigger if exists alumni_profiles_delete_auth_user on alumni_profiles;
drop function if exists alumni_profiles_delete_auth_user();
