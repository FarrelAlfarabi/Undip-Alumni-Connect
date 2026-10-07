/// The version of the privacy policy and community rules. Change this when
/// the text changes: everyone is then asked to accept it again. Never shown
/// on every launch, only when the accepted version differs from this one.
const String kPolicyVersion = '2026-10-04-draft2';

/// "Last updated" date shown in the text, in each language.
const String kPolicyUpdatedId = '4 Oktober 2026';
const String kPolicyUpdatedEn = '4 October 2026';

/// Who runs the app, and how people can reach you (beta values; replace the
/// operator name and the temporary address with the real ones before a public launch). These two
/// values are put into both policy texts (assets/policy/privacy_id.md and
/// assets/policy/privacy_en.md) in place of {{OPERATOR}} and {{CONTACT_EMAIL}}.
const String kOperatorName = 'Lingkaran beta team';
const String kContactEmail = 'lingkaranikafe@gmail.com';

/// I MUST FILL IN: the physical (postal) address of the operator. Shown on
/// Profile > About with the operator name and contact email.
const String kOperatorAddress =
    'Temporary address: Semarang, Jawa Tengah, Indonesia (full postal address to follow)';

/// The two text files. Indonesian first, English second. Replace the text in
/// them at any time; keep the {{...}} tokens where the values should go.
const String kPolicyAssetId = 'assets/policy/privacy_id.md';
const String kPolicyAssetEn = 'assets/policy/privacy_en.md';

/// True when a policy value is empty or still has its `[FILL IN: ...]` text.
/// The release gate (test/release_check_test.dart, run by the CI APK job) uses
/// this so a build for testers cannot go out with an unfilled operator.
bool hasPolicyPlaceholder(String value) =>
    value.trim().isEmpty || value.contains('[FILL IN');
