# Demo Script: Lingkaran closed beta

For showing the closed beta to Mas Gilang, Maria and the first testers. Run it against a demo database, never the live project. Test emails are in `supabase/seed.sql` (for example `ahmad.ramadhan@example.com`).

Say this first: **this is a closed beta. It is free, there is no payment in the app, and there is no real login yet.**

---

## 0. Before you start

- You need the debug APK (GitHub Actions artifact) or `flutter run`, with a `.env` that points to a demo database.
- The demo database needs all migrations up to `20261003170000` applied, and at least one admin row (see the header of `20261003130000_app_admins.sql`).
- Two phones or two sign-ins help: one person with a business, one visitor.

## 1. Welcome and verification

1. The app opens on Welcome. Point at the small **BETA** label and the version.
2. Tap **Get Started**, verify with a seed email.
3. Read the privacy policy summary on the **consent** screen, tick the box, continue.
4. Optional: set a PIN. Say plainly that the PIN is a phone lock, not real security.

## 2. Navigation

Four tabs: **Home, Directory, Market, Profile**. Chat is hidden. The bell (notifications) and **Requests** are on Home.

## 3. Directory and Nearby

1. **Directory**: search by name or company, filter by major, year, industry.
2. Open a profile. Instead of messaging there is **Request contact**: the person decides whether to share a contact.
3. **Nearby** is simulated from each profile's city, not real GPS. Switch the phone to dark mode to show the dark map.

## 4. Register a business (the new core)

1. **Profile > My business** (or the card on Home) > **Register a business**.
2. Fill in name, description, category, optional links, and **Yearly sales**. Explain the UMKM bands: micro up to Rp 2 miliar, small over 2 to 15, medium over 15 to 50, large over 50 (PP 7/2021 Art. 35).
3. Submit. The status is **Pending**. An admin must approve it.
4. Sign in as an admin (**Profile > Admin > Businesses**): approve it. The owner gets an in-app notification.

## 5. Market

1. **Market > Businesses**: the approved business is in the directory.
2. **Market > Products**: as the owner tap **Add a product**, pick the business, fill in, submit. It goes live at once.
3. Show the free limit for the band (for example "2 of 5 used"). Hit the limit to show the message.
4. Explain: unlimited posting is switched on by the team in the dashboard (`unlimited_until`), never inside the app. Nothing is paid in the app.

## 6. Contact, report, block

1. As a visitor, open a product or profile and tap **Request contact**. The owner sees it under **Requests**, can accept (shares the contact) or decline.
2. Use the **...** menu on a product or profile: **Report** (with a reason) or **Block**. Blocked people disappear from every list. **Profile > Blocked users** undoes it.
3. As admin, **Admin > Reports** shows the report.

## 7. Jobs and News

- **Jobs**: anyone verified can post a job and apply. There is no subscriber gate.
- **News**: Ikafe announcements, one way.

## 8. Feedback, About, delete

1. Cause an error (turn the network off, open a list). Show **Send feedback**. Admins read it in **Admin > Feedback**.
2. **Profile > About** shows "Lingkaran v0.9.0 (build N) BETA".
3. **Profile > Delete my account** explains what is removed. Do not run it on a real account.

---

## Say these explicitly

- Closed beta only, about 15 testers.
- No real login. Anyone who knows an email or a profile id can act as that person, admins and account deletion included.
- The directory still sends everyone's email and NIM to every client.
- No push notifications (in-app only), no release signing, no store account, no backups.
- The privacy policy is written by us and needs review before a public launch.
- No fee or revenue share for Ikafe is built.

## If something breaks live

- **"No matching record"**: wrong email or old `.env`. Use another seeded email.
- **Business stays Pending**: nobody with an admin row has approved it. Check `app_admins`.
- **Posting a job fails**: the Stage 3 migration (`20261003090000`) and the new app build must go together.
- **Blank or error screen**: use **Send feedback**, read the error before improvising.
