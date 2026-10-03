# Decisions (unattended run, from 3 Oct 2026)

One line of reason for each. Newest at the bottom.

- **Merge and deploy.** The brief says "do not merge" and "never push to main", but its last line says "mark the PR ready and merge to main" and "deploy to Vercel". I followed the explicit "Never" rules: the PR is marked ready and NOT merged, and the web deploy is NOT changed or triggered. Reason: the DATABASE migrations in this work are not applied yet, and merging the app to main would break job posting on the live site (the Stage 3 rule).
- **Flutter version pinned to 3.47.4** (Dart 3.13.3). Reason: `pubspec.lock` needs Dart 3.13.3 or newer, and this is the oldest stable release that has it.
- **APK build needs a Java 17 setup step.** Reason: the Android build in CI needs it and the runner default can change.
