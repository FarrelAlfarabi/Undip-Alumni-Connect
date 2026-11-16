/// Every alumni_profiles column the app may read. The API roles get select
/// column by column, so a new column needs a grant in the database and a
/// line here.
const String kProfileColumns =
    'id, user_id, name, email, faculty, major, graduation_year, '
    'current_employer, current_role, industry, company, city, '
    'verification_status, created_at, updated_at, '
    'policy_version, policy_accepted_at, deleted_at, bio, linkedin_url';
