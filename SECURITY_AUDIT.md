# Lingkaran security audit (OWASP-style)

Branch `feature/home-hub`. Audited on 2026-09-30. **Part A** (sections 1 to 7)
is the original report and was written before any fix. **Part B** fixed what
can be fixed without real Supabase Auth; its result is in sections 8 to 10 and
in the "After Part B" verdict below. Sections 1 to 7 are kept as written so you
can see what was found.

How I checked: read every migration, seed, Dart screen and config in the repo;
ran the SQL on a throwaway local Postgres (`supabase/tests/security_audit/run_audit.sh`,
fixtures are synthetic `example.com` people only, no seed files loaded); ran
Dart proof tests against fakes. I did **not** touch any live Supabase project,
Vercel deployment or other third party. The only outside lookup was the public
pub.dev advisory list for the locked packages.

Labels: **Confirmed by test**, **Confirmed by reading code**, **Suspected (not verified)**.

---

## After Part B (final gate, same day)

- **Safe to load real alumni data now: STILL NO.** 4 Critical (SA-01, SA-02, SA-03, SA-05) and 5 High (SA-06, SA-07, SA-08, SA-09, and the read side of SA-10) findings are open. All of them need real Supabase Auth, an owner decision, or both.
- **Fixed:** SA-04 (admin takeover, by a server-checked passphrase), SA-12, SA-13, SA-14, SA-16, SA-18, SA-19, SA-22 (backup part). **Partly fixed:** SA-10, SA-11, SA-15, SA-20, SA-24. Details in section 8.
- **Nothing was applied to any live project.** The database fixes are two new migration files with a tested rollback. Do not say "safe" until the auth project (section 9) is done or you accept the risk in writing.

## 1. Verdict (Part A, original)

- **Safe to load real alumni data today: NO.** Anyone with the public anon key can read every alumnus's email and NIM, every private message and every job application, and can act as any user or as the marketplace admin.
- **Top three risks:** (1) email is the only login and every email is world-readable, so anyone can become anyone (SA-03); (2) private messages, applications and CVs are readable by everyone (SA-01, SA-02, SA-11); (3) the admin's profile id is public, so anyone can act as admin (SA-04).
- **Single most urgent fix:** replace the email-match "login" with real Supabase Auth (email OTP) and rewrite the RLS policies around `auth.uid()`. Nothing else removes the top three risks. Until then: no real data.

---

## 2. Findings (sorted by severity)

Severity: Critical = anyone can read or change other people's personal data or gain admin today. High = exploitable with modest effort or exposes personal data. Medium = needs unusual conditions. Low = hardening. Effort: S/M/L. "Blocks real data?" = must be closed before real alumni data is loaded.

| ID | Title | Sev | OWASP | Status | Where | One-line exploit | Recommended fix | Effort | Blocks real data? |
|---|---|---|---|---|---|---|---|---|---|
| SA-01 | Every private message and conversation is world-readable | Critical | A01 | Confirmed by test (P01, P02) | policies `messages_select` (`20260915120000_add_basic_rls.sql:96`), `messages_select_anon` (`20260922120000_restore_anon_write_access.sql:38`), `conversations_select` (`:87`), `conversations_select_anon` (`:32`) | `GET /rest/v1/messages?select=*` with the anon key returns all DMs | Real Supabase Auth; policy `auth.uid() in (participant_one, participant_two)` | L | Yes |
| SA-02 | Every job application (name, email, phone, cover note, CV path) is world-readable | Critical | A01 | Confirmed by test (P03) | policy `job_applications_select` (`20260917100000_add_job_applications.sql:41`) | `GET /rest/v1/job_applications?select=*` | Auth; only the applicant and the job poster may read | L | Yes |
| SA-03 | Whole directory incl. email and NIM readable by anyone, and email is the only login: anyone can verify as anyone | Critical | A01, A04, A07 | Confirmed by test (P04) + by reading `verification_screen.dart` | policy `alumni_profiles_select` (`20260915120000_add_basic_rls.sql:39`); `defaultVerifyEmail` in `lib/screens/verification_screen.dart` | Read any email from the API, type it into Verification, you are that person | Auth with email OTP; hide `email`/`nim` from other users | L | Yes |
| SA-04 | Marketplace admin can be taken over with only the admin's profile id (public) | Critical | A01, A07 | Confirmed by test (P16 to P19) | `marketplace_is_admin`, `marketplace_admin_pending`, `marketplace_review_listing`, `marketplace_report_counts` (`20260930090200_marketplace_functions.sql:14,163,179,218`) | Look up the admin's id by email, call `marketplace_review_listing(<id>, ...)` | Auth (`auth.uid()` in the functions) or a secret admin key checked server-side | M (key) / L (auth) | Yes |
| SA-05 | Every write can be done as any other person (impersonation) | Critical | A01 | Confirmed by test (P11 to P13, P20 to P23) | policies `*_insert` with `check (true)` on `messages`, `conversations`, `job_posts`, `city_chat_messages`, `job_applications`; marketplace functions taking `p_seller`/`p_admin`/reporter ids | Send a DM, post a job, delete someone's listing with `sender_id`/`p_seller` set to their id | Auth; take the actor from `auth.uid()`, never from a parameter | L | Yes |
| SA-06 | Subscription and verification flags are client-settable; paywall is client-side | High | A04 | Confirmed by test (P14, P33) | policies `alumni_profiles_update` and `alumni_profiles_update_anon`; `subscribe_screen.dart`; trigger allows both columns | `PATCH alumni_profiles` `subscription_status=subscribed` for anyone; job `contact_info` is in every read | Set subscription server-side only (payment webhook, service role); move gated fields out of open reads | M | Yes |
| SA-07 | Anyone can edit another person's employer, role, industry, company | High | A01 | Confirmed by test (P15) | `alumni_profiles_update_anon` (`20260922120000_restore_anon_write_access.sql:26`) | `PATCH` another profile's `current_employer` | Auth: update only where `id` belongs to `auth.uid()` | L | Yes |
| SA-08 | Real people's names and emails are in the public repo (seeds and notes), including the demo admin's | High | A07, repo | Confirmed by reading | `supabase/seed.sql:92,104,113,151-153,164` (three real-looking Gmail addresses, shown masked here as `s***@example.com`, `g***@gmail.com`, `m***@gmail.com`, with full names and NIM-style numbers); `docs/archive/PROJECT_NOTES_FULL.md:363,424` (a fourth, `g***@gmail.com`); admin set in `supabase/seed_marketplace.sql:95` | Read the repo, type the admin's email into Verification | Owner decision: replace with `example.com` addresses; scrubbing history needs a rewrite (destructive, not done) | S (tree) / M (history) | Yes |
| SA-09 | No in-app account deletion and no consent capture | High | A04, privacy | Confirmed by reading | no delete UI in `lib/`; Welcome screen has a demo notice only; no `consent` column | A user cannot remove their data; app stores no record of agreement | Add account deletion (both app stores require it) and a consent step with a stored timestamp | M | Yes |
| SA-10 | Notifications and the simulated email log are open: read all, forge, rewrite | High | A01 | Confirmed by test (P05 to P09) | policies `notifications_select/insert/update` (`20260918100000_add_notifications.sql:34-36`), `email_log_select/insert` (`20260918110000_add_email_log.sql:33-34`) | Insert a phishing notification for anyone; read everyone's emails | Revoke direct insert (trigger-only), limit update to `read_at`; reads need auth | S (insert/update) / L (reads) | Yes |
| SA-11 | CV bucket is public, listable, no size or type limit | High | A01, A03 | Confirmed by test (P28 to P30) | bucket `cvs` and policies `cvs_public_read/upload` (`20260917100000_add_job_applications.sql:53-61`); path built in `apply_job_screen.dart` | List every CV path; upload a 1 GB `.html` | Drop the list policy, set size and MIME limits; private bucket + signed URLs needs auth | S / L | Yes |
| SA-12 | No security headers on the web app | Medium | A05 | Confirmed by reading (+ proof test) | `vercel.json` has no `headers` | Clickjacking, sniffing, no CSP or referrer policy | Add CSP, `X-Frame-Options`/`frame-ancestors`, `Referrer-Policy`, `X-Content-Type-Options`, `Permissions-Policy` | S | No |
| SA-13 | Raw exception text is shown to users | Medium | A05, A09 | Confirmed by test (proof test) | `verification_screen.dart:100`, `apply_job_screen.dart:127`, `post_job_screen.dart:70`, `subscribe_screen.dart:41`, `chat_screen.dart:72,92`, `city_group_chat_screen.dart:71,91`, and 10 more `Failed to load ...: ${snapshot.error}` | A failure prints project URL, status codes, SQL error text | Show a friendly message, log the detail nowhere the user sees | S | No |
| SA-14 | Applicant links are opened with no scheme check | Medium | A03 | Confirmed by reading code | `lib/screens/job_applicants_screen.dart:172` (`launchUrl(Uri.parse(url))`); inputs in `apply_job_screen.dart:236-262` have no URL validation and DB has no check | An applicant submits `tel:...`, `sms:...` or a custom scheme; the poster taps it | Allow only `http`/`https`, validate on entry, catch parse errors | S | No |
| SA-15 | No length limits or rate limits on user text | Medium | A04 | Confirmed by test (P24, P25) | `messages.body`, `city_chat_messages.body`, `job_posts.*`, `job_applications.*` have no `check` on length | Post a 1 MB message repeatedly; fill the free database | `check (char_length(...))` limits; per-actor rate limit (needs auth to mean anything) | S / M | No |
| SA-16 | Marketplace `image_url` accepts any string | Medium | A03 | Confirmed by test (P27) | `marketplace_create_listing` / `marketplace_update_listing` and column `image_url` (no check) | Set `image_url` to a tracking pixel on your server (learns each viewer's IP) or `javascript:` | `check (image_url ~ '^https://')`, ideally only the bucket's own URL | S | No |
| SA-17 | Report brigading and listing spam: ids are free to rotate | Medium | A04 | Confirmed by test (P23) | `marketplace_reports_insert` policy (`20260930090100_marketplace_reports.sql:29`); one report per (listing, reporter id) only | Ten reports from ten ids on a rival's listing | Auth, then one report per real person | M | No |
| SA-18 | No audit trail for admin decisions | Medium | A09 | Confirmed by test (P36) | `marketplace_review_listing` records status only, not who or when | An admin action cannot be traced | Add `reviewed_by`, `reviewed_at`; log to an audit table | S | No |
| SA-19 | `.env` is bundled into the web build; build script never checks the key type | Medium | A05 | Confirmed by build + reading (proof test) | `pubspec.yaml:70`; `build/web/assets/.env` exists after `flutter build web`; `scripts/vercel-build.sh` | The file is downloadable by every visitor; a service-role key set in `SUPABASE_ANON_KEY` would ship to the world | Refuse to build if the key's JWT role is not `anon` (or key is not `sb_publishable_`) | S | No |
| SA-20 | Marketplace bucket is listable; type check is by declared MIME and extension only | Medium | A01, A03 | Confirmed by test (P31) + Suspected (MIME sniffing) | `marketplace_public_read` (`20260930090300_marketplace_storage.sql:23`) | List all photo paths; upload a non-image named `.jpg` with an image MIME | Drop the list policy; bucket limits already 2 MB and 3 image types | S | No |
| SA-21 | 6-digit PIN can be brute-forced offline from a rooted device's storage | Low | A02 | Confirmed by reading (`lock_config.dart`) | `lib/lock/pin_hasher.dart` (PBKDF2, 60,000 iterations) | 1,000,000 candidates x 0.4 s | Cannot be fixed with a 6-digit PIN; keep the attempt wipe; say it is a convenience lock | - | No |
| SA-22 | Android auto-backup may copy the secure-storage file; no privacy screen in the app switcher | Low | A02 | Suspected (not verified) | `android/app/src/main/AndroidManifest.xml` has no `allowBackup` setting | Backup restores a useless encrypted blob; screenshot of the last screen in the recents view | `android:allowBackup="false"`; blank the window when backgrounded | S | No |
| SA-23 | Live Supabase project ref is written in public notes | Low | A05 | Confirmed by reading | `docs/archive/PROJECT_NOTES_FULL.md:35,318,576,737,793` | Identifies the live project (it is in the web bundle URL anyway) | Accept, or keep out of docs | S | No |
| SA-24 | Migrations and seeds are applied by hand; rollback exists only for the marketplace | Low | A08 | Confirmed by reading | `supabase/migrations/`, `supabase/rollback_marketplace.sql`; the collision in `docs/archive/PROJECT_NOTES_FULL.md` Session 30 | A wrong migration on the shared DB broke Save (already happened once) | Use a migration tool (Supabase CLI) and a separate project per branch | M | No |
| SA-25 | Dependencies: no known advisory affects the locked versions; 17 are behind | Low | A06 | Confirmed (advisory list checked) | `pubspec.lock` (121 packages, all hosted on pub.dev except SDK ones) | `http` and `shared_preferences_android` have advisories but both are fixed below the locked versions | Re-check before launch; `flutter pub upgrade` for patch bumps | S | No |

Findings I looked for and did **not** find: dynamic SQL or an unsafe `search_path` in any function (all `SECURITY DEFINER` functions set `search_path = public` and use typed parameters, no `execute`); user text rendered as HTML (Flutter draws to a canvas, no WebView or HTML widget in `lib/`); a server that fetches user-supplied URLs (no Edge Functions; `supabase/functions` does not exist); real keys or `.env` files in git history of the branches present in this clone.

---

## 3. Checklist walk-through (A01 to A10)

### A01 Broken access control

Tables and what `anon` can do (the app only ever calls Postgres as `anon`; RLS cannot tell callers apart). Sources: the policies listed above.

| Table | Read | Insert | Update | Delete |
|---|---|---|---|---|
| `alumni_profiles` | all rows, all columns (incl. email, NIM) | no (no policy) | any row; trigger limits columns to employer/role/industry/company/verification_status/subscription_status | no |
| `job_posts` | all (incl. `contact_info`) | any, with any `posted_by` | no | no |
| `job_applications` | all (PII) | any, with any `applicant_id` | no | no |
| `conversations` | all | any pair | no | no |
| `messages` | all | any, with any `sender_id` | no | no |
| `city_chat_messages` | all | any, with any `sender_id` | no | no |
| `notifications` | all | any recipient | any row, any column | no |
| `email_log` | all | any | no | no |
| `announcements` | all | no | no | no |
| `marketplace_listings` | approved rows only | no (functions only) | no (functions only) | no (functions only) |
| `marketplace_reports` | no | yes, on approved listings, any reporter id | no | no |
| `marketplace_admins` | no | no | no | no |

`SECURITY DEFINER` functions that take a client-supplied profile id. All are executable by `anon`. Without auth, "knowing or guessing the id" is enough, and ids are readable from `alumni_profiles`.

| Function | What an attacker who has another profile's id can do |
|---|---|
| `marketplace_is_admin(p_profile)` | Confirm whether an id is an admin (oracle) |
| `marketplace_create_listing(p_seller, ...)` | Post a listing as that person, if that person is a subscriber |
| `marketplace_update_listing(p_seller, p_listing, ...)` | Edit that person's listing (it goes back to `pending`), redirect `image_url`, change contact info |
| `marketplace_set_sold(p_seller, p_listing)` | Mark that person's approved listing sold |
| `marketplace_delete_listing(p_seller, p_listing)` | Delete that person's listing (any status) |
| `marketplace_my_listings(p_seller)` | Read that person's listings incl. pending and rejected, with contact info |
| `marketplace_admin_pending(p_admin)` | Read the review queue with contact info (admin id only) |
| `marketplace_review_listing(p_admin, ...)` | Approve or reject any pending listing (admin id only) |
| `marketplace_report_counts(p_admin)` | Read report counts (admin id only) |
| trigger functions (`notify_poster_on_application`, `alumni_profiles_restrict_update`) | Not callable: execute is revoked from `public`, `anon`, `authenticated` |

Marketplace specifics: pending and rejected listings are hidden from direct reads (control C6 passes) but not from `marketplace_my_listings` (P20) or the admin functions (P18). Reports are write-only for anon (C4 passes). Direct writes to listings are closed (C2 passes).

Storage: buckets `cvs` and `marketplace` are public. **List** is open to anon on both (P28, P31, from the `select` policies); **read** by URL is open by design; **upload** is open to anon on both (P29); **overwrite and delete** are not possible (no update or delete policy). `cvs` has no size or type limit (P30). `marketplace` limits 2 MB and JPEG/PNG/WebP by the bucket settings and by extension in the policy. Paths: `cvs` = `<job uuid>/<epoch ms>_<name>`, `marketplace` = seller-scoped path built by the app; both are guessable in part but moot because listing is open.

### A02 Cryptographic failures and data protection
- PIN: salted PBKDF2-HMAC-SHA256, 16-byte random salt, 60,000 iterations, constant-time compare, stored in Keychain / Keystore-backed storage. Verified against published test vectors. Weakness is inherent to a 6-digit PIN (SA-21).
- Secure storage holds: profile id, display name, masked email, PIN hash, counters, biometric flag. Nothing sensitive is in plain storage. Web: nothing is stored (no lock on web).
- HTTPS: Supabase and Vercel are HTTPS; the app has no `http://` endpoints in `lib/`. Marketplace `image_url` allows `http:` and any other scheme (SA-16).
- The alumni email and NIM travel and rest unprotected by design of the open policies (SA-03).

### A03 Injection and unsafe input
- SQL: no dynamic SQL, `search_path` fixed, typed parameters. Confirmed by reading.
- Filters: `.or('participant_one.eq.$myId,...')` (`messages_list_screen.dart:54`, `profile_detail_screen.dart:89`) interpolates ids that come from the database, not from a text box, so no injection today. There is no `ilike` on user input; search is done client-side. Suspected-low: if a future change puts free text into `.or()`, it becomes a PostgREST filter injection.
- URLs: SA-14 (applicant links), the marketplace shop link is checked by the DB (`^https?://\S+$`) and by `Uri.tryParse(...).hasScheme` in the app; SA-16 for images.
- Uploads: CV type is checked only by the file picker's extension list (client side) (SA-11); listing photos by extension in policy and MIME in bucket (SA-20).
- Web XSS: none found; text is drawn on a canvas.

### A04 Insecure design
- Trust in client flags: SA-06. Verification by email match: SA-03. "Email exists?" can be probed trivially (same read); ids can be enumerated (SA-03). No abuse limits: SA-15, SA-17.

### A05 Security misconfiguration
- Bundle: `assets/.env` is in the build (SA-19). The repo has only `.env.example` with placeholders; I could not inspect the deployed key (see section 6). No `TEMP` or debug code left in `lib/`. No headers: SA-12. Verbose errors: SA-13.

### A06 Vulnerable and outdated components
- SA-25. `flutter pub outdated`: 2 direct packages have newer major versions (`cupertino_icons`, `google_fonts`), 12 transitive are upgradable. pub.dev advisories: only `http` (fixed in 0.13.3) and `shared_preferences_android` (fixed in 2.3.4); locked versions are 1.6.0 and 2.4.28, so not affected.

### A07 Identification and authentication failures
Exactly what someone needs:
- **To act as another user:** know or read their email (the whole list is readable), type it in Verification. No OTP, no password. Or skip the app: call the API with the anon key and put their profile id in any write.
- **To act as an admin:** the admin's email is in the public repo (`supabase/seed_marketplace.sql:95` makes the profile with the seed-owner's Gmail the admin; `README.md:79` and `MARKETPLACE_CHECKLIST.md:8` repeat it). Steps: (1) open the app, (2) type that email in Verification, (3) the Marketplace tab shows the admin queue. Or: (1) `GET /rest/v1/alumni_profiles?select=id&email=eq.<that email>`, (2) `POST /rest/v1/rpc/marketplace_review_listing` with that id. Whether the deployed database really has that person as admin depends on whether the seed was applied there (not verified).
- Real personal data in the repo: SA-08 (three Gmail addresses with full names in `seed.sql`, a fourth in `docs/archive/PROJECT_NOTES_FULL.md`). I did not use any of it in a test; the audit fixtures are all `example.com`. Whether the NIM values in the seed are real is not known (Suspected).
- Lock screen: 5 wrong PINs wipe local data; a 10 s wait starts from the 3rd wrong try; counters persist across restarts; "Switch account" and "Forgot PIN" clear local data only and go to Welcome. It is a device lock; it adds nothing against SA-03.

### A08 Software and data integrity
- SA-24. Rollback exists only for the marketplace. All dependencies come from pub.dev (`source: hosted`) except the Flutter SDK packages.

### A09 Logging and monitoring
- App logs no PII (no `print` in `lib/`). The DB stores full email bodies in `email_log` (readable by all, SA-10). Raw error text on screen: SA-13. No audit trail for admin actions: SA-18. No way to notice abuse: no rate limits, no alerts (Suspected: the Supabase dashboard has logs, but I did not look).

### A10 SSRF (low priority)
- No backend code fetches a URL supplied by a user (no Edge Functions, no database HTTP extension used in migrations). Confirmed by reading.

---

## 4. Personal-data inventory (UU PDP)

Who can read = as `anon` today. "User can delete?" = through the app.

| Table | Column(s) | Who can read | User can delete? |
|---|---|---|---|
| `alumni_profiles` | `name`, `email`, `nim`, `faculty`, `major`, `graduation_year` | Anyone with the anon key | No |
| `alumni_profiles` | `current_employer`, `current_role`, `industry`, `company`, `city` | Anyone | Can overwrite, not delete |
| `alumni_profiles` | `verification_status`, `subscription_status`, `created_at`, `updated_at`, `user_id` | Anyone | No |
| `job_posts` | `title`, `company`, `description`, `contact_info`, `posted_by` | Anyone | No |
| `job_applications` | `full_name`, `email`, `phone`, `linkedin_url`, `portfolio_url`, `cover_note`, `cv_path` | Anyone | No |
| Storage `cvs` | uploaded CV files (contain personal data) | Anyone with the URL or list access | No |
| `conversations` / `messages` | participants, `body` | Anyone | No |
| `city_chat_messages` | `sender_id`, `city`, `body` | Anyone | No |
| `notifications` | `recipient_id`, `title`, `body`, `read_at` | Anyone | No |
| `email_log` | `recipient_email`, `subject`, `body` | Anyone | No |
| `marketplace_listings` | `seller_id`, text, `city`, `contact_info` (phone or WhatsApp), `shop_url`, `image_url` | Approved rows: anyone. Pending/rejected: anyone with the seller id (SA-04/05) | Seller can delete own listings |
| Storage `marketplace` | listing photos | Anyone | Cannot delete files |
| `marketplace_reports` | `reporter`, `reason`, `note` | Nobody via the API (admin reads counts only) | No |
| On device (secure storage) | profile id, display name, masked email, PIN hash | Only that phone | Yes (Switch account, Forgot PIN, Sign out) |

- **In-app account deletion: does not exist.** Both app stores require it for apps with accounts.
- **Consent: not captured anywhere.** The Welcome screen only says it is a demo build.

---

## 5. Repo hygiene

- `.gitignore` covers `.env`, `.env.*` (keeps `.env.example`). `git log --all` in this clone shows only `.env.example` ever committed, and no key-like strings (JWTs, `sb_secret_`, private keys, tokens) in any commit.
- Real personal data in the working tree and history: SA-08.
- Not checked: other branches (`main`, `demo`, `feature/production-hardening`, `feature/ai-job-description`) are not in this clone, so their history was not scanned.

---

## 6. What I could not check, and why

- **The live Supabase project** (policies actually applied, whether the seed admin exists, whether Realtime or extra functions are enabled, dashboard logs): rules forbid touching it, and read-only queries need your approval. The audit is of the repo's migrations. The live database has had RLS changed by hand before (Session 30), so it may differ.
- **The deployed Vercel site** (real response headers, the deployed `.env` contents): not probed. SA-12 and SA-19 are from the config in the repo.
- **The real key in `SUPABASE_ANON_KEY`:** I only have `.env.example`. I cannot say whether the deployed key is the publishable one.
- **Other branches' git history:** not in this clone.
- **Real Android/iOS behaviour** (Keystore, backup, biometrics): no device or SDK here (SA-22 is Suspected).
- **Storage MIME sniffing and real Supabase Storage enforcement:** the local stub models policies and bucket settings, not the Storage service itself.
- **PostgREST behaviour** (OpenAPI listing, rate limits, CORS): the stub has no PostgREST.
- **Tools I would use, not installed (per your rule):** `semgrep` (code patterns), `gitleaks` or `trufflehog` (secrets in all branches' history), the Supabase CLI `supabase db lint` and the dashboard Security Advisor (RLS gaps on the real project), `zap-baseline` (headers on the deployed site).

---

## 7. Suggested fix order (grouped into commits)

1. **Web hardening** (SA-12, SA-19): security headers in `vercel.json`; build script refuses a non-publishable key.
2. **Input safety in the app** (SA-13, SA-14): friendly error messages; http/https-only link opening with validation.
3. **Storage and abuse limits, migration only** (SA-10 insert/update, SA-11 list/size/type, SA-15, SA-16, SA-18, SA-20): one new migration `..._security_hardening.sql`, tested on the local stub, not applied anywhere.
4. **Admin takeover mitigation** (SA-04): a server-checked admin passphrase in the marketplace admin functions (stops "admin id is enough"). Not a substitute for auth.
5. **Repo hygiene** (SA-08): owner decision on replacing real emails in seeds (changing them and re-running the seed on the live DB would change live logins, so I do not do it unasked).
6. **Real Supabase Auth project** (SA-01 to SA-07, SA-09, SA-10 reads, SA-17): separate, larger. Needs: email OTP flow, a `user_id` link for every profile, rewrite of every policy and function around `auth.uid()`, a data migration for existing users, an account-deletion flow, a consent step, a payment webhook for subscriptions.

---

## 8. Fix status after Part B

"Fixed" means: a test failed before the change and passes after. Database items were tested on the local stub only (`bash supabase/tests/security_audit/run_audit.sh pre` versus `post`, plus `bash supabase/tests/run_local.sh`); they are not applied to any live project.

| ID | Result | What was done, and what is left |
|---|---|---|
| SA-01 | **Open** | Needs auth (participants-only policies). |
| SA-02 | **Open** (reads) | Applications still world-readable. CV file listing closed and CV size/type limited (see SA-11). Needs auth. |
| SA-03 | **Open** | Needs auth (email OTP) and hiding `email`/`nim` from other users. |
| SA-04 | **Fixed for admin actions** | Admin functions now need a passphrase checked against a bcrypt hash (`20260930100100_security_admin_key.sql`); the app asks for it. Left: the admin id is still readable and `marketplace_is_admin(id)` still confirms it (P16, P17); it is a shared secret, not real auth. Nobody is admin until the owner runs `marketplace_set_admin_key`. |
| SA-05 | **Open** | Needs auth: actor from `auth.uid()`. |
| SA-06 | **Open** | Needs a server-side payment path (webhook + service role). |
| SA-07 | **Open** | Needs auth. |
| SA-08 | **Open** | Owner decision: replace real emails in seeds/notes (changing the seed and re-running it on the live DB changes live logins). Removing them from git history needs a rewrite of history, which I did not do. |
| SA-09 | **Open** | No account deletion or consent capture; both need auth to be safe (otherwise anyone could delete anyone). |
| SA-10 | **Partly fixed** | Direct insert into `notifications` and `email_log` removed; notifications can only change `read_at` (`20260930100000_security_hardening.sql`). Reads are still open (needs auth). |
| SA-11 | **Partly fixed** | Listing closed, 5 MB limit, pdf/doc/docx only, matching app checks. CVs are still public by exact URL (private bucket needs signed URLs, which need a session). |
| SA-12 | **Fixed** | Security headers in `vercel.json`. Verified in Chromium against a local build. The CDN path (CanvasKit from gstatic) could not be loaded from this sandbox: check the Vercel preview. |
| SA-13 | **Fixed** | 16 screens show safe messages only. |
| SA-14 | **Fixed** | http/https-only link opening and validation. |
| SA-15 | **Partly fixed** | Length limits added (new and changed rows). No rate limits: they mean little while ids can be rotated (needs auth). |
| SA-16 | **Fixed** | `image_url` must be https (new and changed rows). |
| SA-17 | **Open** | Needs auth. |
| SA-18 | **Fixed** | `reviewed_by`, `reviewed_at` recorded. |
| SA-19 | **Fixed** (repo side) | Build refuses non-publishable keys and non-https URLs. The deployed key itself is still unchecked. |
| SA-20 | **Partly fixed** | Listing closed. MIME sniffing not addressed (Supabase checks the declared type). |
| SA-21 | **Accepted** | Inherent to a 6-digit PIN. |
| SA-22 | **Partly fixed** | `allowBackup="false"`. No privacy screen in the app switcher. |
| SA-23 | **Open (accepted)** | The project ref is in public notes. |
| SA-24 | **Partly fixed** | Rollback file for the security migrations (tested twice on a fresh database) and the local test now re-runs all `2026093*` migrations in order. Still applied by hand. Warning: re-running only the original marketplace migrations brings back the old id-only admin functions. |
| SA-25 | **Checked** | No advisory affects the locked versions. No upgrades made. |

### Final re-run of the checklist
- A01: closed for notifications insert/update, CV and photo listing, admin actions. Open for every read of personal data and every impersonation write (auth).
- A02: unchanged; backup off on Android.
- A03: links and image URLs fixed; CV type checked in app and bucket.
- A04: flags still client-settable (SA-06); length limits added; no rate limits.
- A05: headers, key check, no raw errors.
- A06: unchanged, no advisories affect locked versions.
- A07: admin needs a passphrase; user "login" is still an email match.
- A08: rollback added; still manual.
- A09: raw errors gone; admin decisions traced; no PII logging added.
- A10: none.

Proof status: the SQL probes now show 13 weaknesses fixed (P06, P07, P09, P18, P19, P24, P25, P27, P28, P29, P30, P31, P36) and 19 still present; controls C1 to C7 hold.

---

## 9. The real Supabase Auth project (not started)

This is the only thing that removes the Critical findings. It is a separate, larger piece of work; I did not start it.

**What it involves**
1. Email OTP (or magic link) sign-in with Supabase Auth. First sign-in "claims" the alumni profile whose email matches, once, by a SECURITY DEFINER function that sets `alumni_profiles.user_id = auth.uid()`.
2. Rewrite every policy and function around `auth.uid()`: profiles (a view without `email`/`nim` for other users; update only your own row), messages and conversations (participants only), applications (applicant and job poster only), notifications (recipient only), city chat (signed-in only), marketplace functions (actor from `auth.uid()`, admins by role), drop the simulated email log or restrict it to the recipient.
3. Storage: private buckets, paths prefixed by the user id, signed URLs.
4. Subscription changed only server-side (payment webhook with the service role).
5. App: OTP screens replace Verification; remove every client-supplied id; the lock screen becomes a local unlock of a real session.
6. Account deletion and a consent step with a stored timestamp (UU PDP).
7. Rollout: a separate production Supabase project, data migration for existing users, invite or claim flow.

**Estimate (one developer):** 3 to 5 weeks. Design and decisions 3 to 4 days; database rewrite with local tests about 1 week; app changes about 1 week; migration, rollout and QA about 1 week; buffer for OTP email delivery and store review.

**Decide first**
- Who sends the OTP email (Supabase's default sender is rate-limited; you need your own SMTP and a sender domain).
- What to do with alumni whose listed email is dead or shared.
- Payment provider for subscriptions (Midtrans or Xendit) and who holds the merchant account.
- Whether the simulated email inbox and city chat stay, and who may read them.
- Who the admins are and how they sign in.
- Consent wording and retention period (get a lawyer's read for UU PDP).
- A separate production project, and whether the current open demo stays online.

---

## 10. Manual steps for you (owner), in order

1. Apply the two `2026093010*` migrations on a **separate** project or a Supabase branch database first, never straight on the shared one. Check a CV upload, a listing photo, and opening a notification.
2. Run `select marketplace_set_admin_key('<admin profile uuid>', '<16+ character passphrase>');` in the SQL editor.
3. Deploy a Vercel preview and check the app loads with the new headers (CanvasKit comes from the Google CDN). If the Supabase project uses a custom domain, add it to `connect-src` in `vercel.json`.
4. Check that `SUPABASE_ANON_KEY` on Vercel is the publishable/anon key (the build now refuses anything else).
5. Decide on SA-08 (real emails in the public repo).


---

## 11. Known gaps for the closed beta (2026-10-04)

Added after the free-launch work (Stages 0 to 9, branch `feat/free-launch-business-directory`). These are the gaps that remain on purpose for a closed beta of about 15 people. None of them is fixed by the new migrations. Do not open the app to the public until the first three are closed.

**Not safe for a public launch**
1. **No real login.** Verification is still an email match, not a Supabase Auth session. Anyone who knows an email or a profile id can act as that person. That includes admins (rows in `app_admins`), requests, reports, blocks and **account deletion** (`account_delete`). The typed HAPUS and the final confirm only stop accidents.
2. **The directory still sends every person's email and NIM to every client.** Hiding them needs a view and Auth (section 9).
3. **The public web version uses the same database.** Anyone with the site address can reach the same data and functions.
4. **The privacy policy is self-written.** It says what the code stores. It needs a lawyer's review (UU PDP) before a public launch. Operator name and contact email are still placeholders in `lib/config/policy_config.dart`.

**What the new migrations do protect (proven with anon-role tests, `supabase/tests/run_beta_local.sh`)**
- Business status, approved band, `unlimited_until`, post limits, shared contacts, admin rights, notifications and feedback rows cannot be edited with the anon key. They are changed only through the checked functions or in the dashboard.
- The app role can only insert feedback (no read, no update, no delete). 10 per profile per day.
- This is protection against accidents and casual abuse. Because of gap 1, a person who knows another person's profile id can still call the checked functions as that person.

**Missing**
- Push notifications (in-app only).
- Release signing (testers get a debug APK), store accounts.
- Database backups (the free plan has none; export from the dashboard by hand).
- Files of a deleted account (product photos, CVs) are only queued in `storage_cleanup_queue`; the buckets do not let the app delete files. Clean them in the dashboard.
- The old seed data still holds real names and emails (SA-08).
- Fonts load from Google Fonts at run time (told in the policy).

**Not verified**
- Anything against the live Supabase project, real phones, the CI APK build with the real secrets, the web build.
