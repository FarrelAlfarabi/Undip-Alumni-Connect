# Decisions (unattended run, from 3 Oct 2026)

One line of reason for each. Newest at the bottom.

- **Merge and deploy.** The brief says "do not merge" and "never push to main", but its last line says "mark the PR ready and merge to main" and "deploy to Vercel". I followed the explicit "Never" rules: the PR is marked ready and NOT merged, and the web deploy is NOT changed or triggered. Reason: the DATABASE migrations in this work are not applied yet, and merging the app to main would break job posting on the live site (the Stage 3 rule).
- **Flutter version pinned to 3.47.4** (Dart 3.13.3). Reason: `pubspec.lock` needs Dart 3.13.3 or newer, and this is the oldest stable release that has it.
- **APK build needs a Java 17 setup step.** Reason: the Android build in CI needs it and the runner default can change.
- **Request to contact is a speed bump, not security.** The app has no real login, so the profile ids sent to the database are not authenticated. Anyone who knows a requester's profile id could ask the database for that person's accepted contact. The database still enforces who may read `shared_contact` (only the requester id, only after accept), the daily limit and the 30 day cool-down. Reason: the real fix is Supabase Auth, which is out of scope for the beta.
- **Business edits.** The owner can edit a business only while it is pending or rejected. Reason: edits to an approved business would skip review.
- **Products and review.** A business product is approved at creation and stays approved when its owner edits it. An admin can still reject or hide it. Reason: decision 7.
- **A rejected product still counts toward the limit** until it is deleted (only sold products and deleted ones are free). Reason: otherwise an owner could rotate rejected items to avoid the limit.
- **Job posts need a verified poster** (replaces the subscriber rule). Reason: keep some database guard on `job_posts` after the subscription rule was removed.
