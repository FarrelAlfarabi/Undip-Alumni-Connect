/// Every alumni_profiles column the app may read. NIM is left out on purpose:
/// 20261018120000_hide_nim.sql stops the API roles reading it, so a bare
/// select() on the table fails. NIM comes from profile_nim() for the person
/// it belongs to and for admins. A new column needs a grant in the database
/// and a line here.
const String kProfileColumns =
    'id, user_id, name, email, faculty, major, graduation_year, '
    'current_employer, current_role, industry, company, city, '
    'verification_status, created_at, updated_at, '
    'policy_version, policy_accepted_at, deleted_at, bio, linkedin_url';
