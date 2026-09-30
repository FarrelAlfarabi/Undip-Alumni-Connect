# Lingkaran security audit (OWASP-style)

Branch `feature/home-hub`. Audited on 2026-09-30. **Part A (this file's first
version): report only, no fixes.** Part B updates the "Fix status" section at
the bottom.

How I checked: read every migration, seed, Dart screen and config in the repo;
ran the SQL on a throwaway local Postgres (`supabase/tests/security_audit/run_audit.sh`,
fixtures are synthetic `example.com` people only, no seed files loaded); ran
Dart proof tests against fakes. I did **not** touch any live Supabase project,
Vercel deployment or other third party. The only outside lookup was the public
pub.dev advisory list for the locked packages.

Labels: **Confirmed by test**, **Confirmed by reading code**, **Suspected (not verified)**.

---

## 1. Verdict

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
| SA-08 | Real people's names and emails are in the public repo (seeds and notes), including the demo admin's | High | A07, repo | Confirmed by reading | `supabase/seed.sql:92,104,113,151-153,164` (three real-looking Gmail addresses, shown masked here as `f***@gmail.com`, `g***@gmail.com`, `m***@gmail.com`, with full names and NIM-style numbers); `PROJECT_NOTES.md:363,424` (a fourth, `g***@gmail.com`); admin set in `supabase/seed_marketplace.sql:95` | Read the repo, type the admin's email into Verification | Owner decision: replace with `example.com` addresses; scrubbing history needs a rewrite (destructive, not done) | S (tree) / M (history) | Yes |
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
| SA-23 | Live Supabase project ref is written in public notes | Low | A05 | Confirmed by reading | `PROJECT_NOTES.md:35,318,576,737,793` | Identifies the live project (it is in the web bundle URL anyway) | Accept, or keep out of docs | S | No |
| SA-24 | Migrations and seeds are applied by hand; rollback exists only for the marketplace | Low | A08 | Confirmed by reading | `supabase/migrations/`, `supabase/rollback_marketplace.sql`; the collision in `PROJECT_NOTES.md` Session 30 | A wrong migration on the shared DB broke Save (already happened once) | Use a migration tool (Supabase CLI) and a separate project per branch | M | No |
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
- Real personal data in the repo: SA-08 (three Gmail addresses with full names in `seed.sql`, a fourth in `PROJECT_NOTES.md`). I did not use any of it in a test; the audit fixtures are all `example.com`. Whether the NIM values in the seed are real is not known (Suspected).
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
