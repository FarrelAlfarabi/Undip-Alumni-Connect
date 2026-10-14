# Project notes (summary)

Full session log (42 entries, Sept to Oct 2026): `docs/archive/PROJECT_NOTES_FULL.md`.
Every fact below comes from that file.

- **Scope:** faculty-wide, not campus-wide. Built for Ikafe (alumni of the Faculty of Economics and Business, UNDIP). The Directory filters by Major, not Faculty. Do not build campus-wide assumptions into the data model or UI.
- **Name:** renamed to "Lingkaran" on 30 Sep 2026. Not renamed: repo, Dart package `undip_alumni_connect`, Android/iOS bundle ids, Vercel project and URL.
- **Pricing:** 30 Sep 2026 notes record Rp 99.000/year, no monthly plan. The 4 Oct 2026 entry replaced this: free, no payment in the app, subscription removed.
- **Chat:** hidden behind one switch; "request to contact" replaces it (4 Oct 2026).
- **Features built:** alumni directory, job board with applications, announcements, Nearby Alumni map, business directory (UMKM bands), marketplace from approved businesses, report and block, in-app notifications, account deletion with privacy policy and consent, PIN lock, four tabs (Home, Directory, Market, Profile).
- **Admins:** rows in `app_admins`. The old admin passphrase is ignored (4 Oct 2026).
- **Security audit (30 Sep 2026):** 5 Critical, 6 High, 9 Medium, 5 Low. Verdict then: not safe to load real alumni data. No real login yet. Details: `SECURITY_AUDIT.md`.
- **Beta hardening (6 Oct 2026):** `verification_status` set only by `verify_alumni_email()`; `email_log`, chat tables and `notifications` closed to the public key; release gate fails while `lib/config/policy_config.dart` has `[FILL IN]`.
- **Performance (7 Oct 2026):** CI builds a release APK; tabs built on first open; refetch only after 2 minutes away; directory and market capped at 500 rows.
- **Free launch live (5 Oct 2026):** the nine migrations (`20261003090000` to `20261003170000`) are applied to the live `undip-alumni-connect-demo` project, by hand through the Supabase tool and SQL Editor (the hand-run pieces are in `docs/APPLY_REMAINING.sql`). PRs 9 and 10 are merged, Vercel builds production from `main`, and Gilang, Maria and Farrel are in `app_admins`. A legal and accessibility pass added `docs/LEGAL_AUDIT.md`, drafts in `docs/legal/` and privacy policy v2.
- **Open:** policy operator name, contact email and address were filled with beta values and need real ones before any public launch; self-host Google Fonts and CanvasKit; review the 12 old seed listings; no real login yet (anyone who knows an email can act as that person) and the directory still sends every email and NIM to every client; Terms and privacy policy need legal review. See `docs/OPEN_ITEMS.md`.
- **Latest checks recorded:** analyze clean, 594 tests pass (7 Oct 2026). Release APK build and a real phone not verified.
- **Newer logs:** `docs/STAGE_LOG.md`, `docs/DECISIONS.md`.
