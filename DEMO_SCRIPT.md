# Demo Script — UNDIP Alumni Connect (for Mas Gilang / Ikafe)

Written for the Sep 23 demo. Assumes the app is already running (see README/PROJECT_NOTES for how to launch it — Flutter web via `flutter run -d web-server` or `flutter build web` + a static server, with the real `.env` credentials in place).

**Everything below uses dummy/seed data. No real alumni, no real payment, no real NIM verification — say this up front if it isn't obvious from context.**

---

## 0. Before you start

- Confirm you're on branch `claude/eloquent-maxwell-pzaky1` and have pulled the latest.
- Confirm `.env` has the real Supabase URL/anon key (ask if you don't have them).
- Have this test email ready: **`ahmad.ramadhan@example.com`** — seeded as `free`, not subscribed, so the paywall demo works live. Don't use `bunga.ayu@example.com` for the main walkthrough; she's pre-subscribed and would skip the paywall moment.
- Optional second test email if you want to show the "no match" rejection path: anything not in the seed data, e.g. `notreal@example.com`.

---

## 1. Verification (the "core wedge": verified identity)

1. Launch the app — it opens directly on the **Verify Your Alumni Status** screen.
2. Enter `ahmad.ramadhan@example.com` → tap **Verify**.
3. Narrate: *"This checks against Ikafe's alumni records. For the demo it's an exact-match against sample data — in production this becomes a real NIM cross-check against Ikafe's official graduate list."*
4. You land on the **Profile** tab automatically — Ahmad's academic info (NIM, faculty, major, graduation year) and employment info (employer, role, industry, company) are shown.
5. Point out: academic fields came from verification and aren't editable. Employment fields are, via **Edit Employment Info**.

**Optional — show the rejection path:** go back, enter a made-up email, show the "No Matching Record" state. Demonstrates the gate actually gates.

---

## 2. Bottom navigation

Point out the 5 tabs: **Profile, Alumni, Jobs, Chat, News** — mirrors the bottom nav from the pitch deck slides already shown to Gilang.

---

## 3. Alumni Directory

1. Tap **Alumni**. Note the two tabs under the header: **Directory** and **Nearby** — you land on Directory.
2. Show the search box — type a company name, e.g. "Tokopedia" or "Gojek".
3. Show the three filter dropdowns — filter by **Faculty**, **Graduation Year**, **Industry**. Combine two filters to show it's a real AND filter, not just search.
4. Tap any alumnus's row → their profile opens read-only. Point out: email is hidden here (only visible on your own profile) — browsing is free, but you don't get everyone's contact info for free, that's the subscription's job.
5. At the bottom of another alumnus's profile: the **Subscribe to Message** button. Don't tap it yet — save the paywall moment for Jobs, it's the same mechanism and you only need to show it working once.
6. Back out to the Directory tab, then tap the **Nearby** tab next to it. Explain clearly: this is simulated from each profile's city, not real GPS — the app never asks for or tracks anyone's location. It's here to show the concept for later, not something live today.
7. Tap the **Map** toggle (next to List) — a Google-Maps-styled view laid out over real relative positions of the seed cities, with one marker per alumnus (a small initials bubble, same visual language as Google Maps' live people-sharing) plus a blue "You" marker. Pinch/drag to zoom and pan. *"Positions are simulated from each profile's city, same as the list — still no real GPS, no map tiles, no Google Maps API key involved."*
8. Hover (or long-press) a marker for a quick name + distance preview; tap it to open that alumnus's profile, same as tapping a row in List view.
9. Below the map, tap a **city chip** (e.g. "Semarang (4)") → a sheet opens with who's there and two networking actions: **Open [City] Group Chat** (a real in-app group chat, not gated behind subscription) and **Invite via WhatsApp** (opens WhatsApp with a prefilled invite message you'd send yourself — WhatsApp has no way to auto-create a group from a link, say this plainly if asked). *"This is the answer to 'don't make me message 20 people one by one' — a whole city's alumni in one place."*
10. Back out to Profile.

---

## 4. Job Board — the monetization moment

This is the most important part of the demo. Take it slow.

1. Tap **Jobs**. Three seeded postings are visible: Product Manager @ Gojek, Business Analyst @ Bank Mandiri, Backend Engineer @ Tokopedia.
2. (Optional) Show search + filters: type part of a title/company/description into the search box, or use the **Industry**/**Company** dropdowns — the list narrows live.
3. Tap into any job's card → full detail view opens.
4. Point at the **Contact: locked** section: *"Anyone can browse and read the full posting for free. Contacting the poster is the paid action — this is the app's main monetization mechanism."*
5. Tap **Subscribe to Contact** → the paywall screen appears, showing the pricing (Rp 25.000/month or Rp 250.000/year — say clearly these numbers are a placeholder, not finalized).
6. Tap **Subscribe Now (Demo)** — note out loud: *"This is a demo button, no real payment happens. In production this becomes Midtrans or Xendit."*
7. You're returned to the job detail — contact info is now unlocked and visible.
8. **Go back to the job list and open a *different* job.** Its contact info should also now show unlocked — this proves the subscription applies across the whole app, not just the one job you were looking at.
9. Go to the **Profile** tab — a **Subscribed** badge now shows on the profile card, confirming the same state everywhere.
10. (Optional, if time allows) With contact unlocked, the button on that job detail now says **Apply to this Job** instead — tap it, fill in the application form (name/email are prefilled, LinkedIn/portfolio/CV are optional), submit. *"Applying is a step further than just seeing contact info — it goes into a real applications table the poster can review."*

---

## 5. Post a Job

1. Back on the **Jobs** tab, tap the **Post a Job** floating button.
2. Fill in a quick example (e.g. Title: "Marketing Intern", Company: "Ikafe", Industry: "Nonprofit", Description: one line, Contact: an email).
3. Point out the **"Notify me when someone applies"** toggle — on by default. *"In this demo that's an in-app applicant count on the job's own page, not a real push or email notification — that's a post-demo build item."*
4. Tap **Post Job** — it appears at the top of the list immediately (newest first).
5. (Optional) Open the job you just posted — as its owner you see an applicant-count banner instead of the Apply button, with a **View Applicants** link showing everyone who applied (name, contact, LinkedIn/Portfolio/CV chips).

---

## 6. Messaging

1. Go to **Alumni**, tap into any other alumnus's profile.
2. Since you're already subscribed (from step 4), the button now says **Message** instead of **Subscribe to Message** — tap it.
3. A conversation opens. Type a message, send it — it appears immediately in the thread.
4. Go to the **Chat** tab — the conversation you just started is listed there.
5. (Optional, once you have 2+ conversations) Show search + filter: type part of a name into the search box, or use the **Faculty** dropdown — narrows the conversation list live.
6. Note: no realtime push yet — the thread refetches after you send, and the refresh icon in the chat's top bar pulls in the other side's replies. Fine for a demo, call it out only if asked.

**Optional — show both sides of a conversation:** tap the sign-out icon (top right of the Profile tab), verify as the alumnus you messaged (e.g. `siti.azizah@example.com`), open **Chat** — the conversation is there from their side. Reply, sign out, come back as Ahmad, hit refresh in the thread.

---

## 7. Announcements

1. Tap **News**.
2. Three seeded Ikafe announcements are shown (Reuni Akbar, mentoring beasiswa, jadwal temu alumni per fakultas) — one-way broadcast, source labeled "Ikafe", no comment/reply UI. Point out this needs no moderation from Farrel — Ikafe posts, alumni read.

---

## 8. Closing points (say these explicitly, don't assume they're obvious)

- Everything shown is **dummy data** — 24 seed alumni, 3 seed jobs, 3 seed announcements. No real Ikafe data is connected yet.
- **No real payment** — the subscribe button is a visual demo only.
- **No real NIM verification** — email exact-match stands in for it in this build.
- **Known open items**, worth surfacing to Gilang directly rather than waiting to be asked:
  - Whether Ikafe actually has a usable path to NIM data at all is still unconfirmed (see Master Plan doc — this is the single biggest blocker to the *production* version, not the demo).
  - Nearby Alumni (list, map, and group chat/WhatsApp invite) is in this demo, but as a concept mockup only — simulated from each profile's city, not real GPS. Real location-sharing has no safety design yet (opt-in, granularity, data retention all undecided) and isn't something to promise a date for.
  - No real security hardening (RLS is off on the database) — fine for a closed demo, not fine to leave that way past this point.

---

## If something breaks live

- **"No matching record" for a real test email** — you likely mistyped it or are using a stale `.env`. Fall back to `ahmad.ramadhan@example.com`, `siti.azizah@example.com`, `bagas.prasetyo@example.com`, `clara.putri@example.com`, or `rizky.yusuf@example.com` — all five are seeded `free` (so all show the paywall live) and verified.
- **Blank/error screens** — check the terminal for the actual error before improvising; don't guess out loud in front of Gilang.
- **Subscribe button doesn't seem to unlock anything** — confirm you're looking at a job/profile that was reloaded after subscribing (opening the exact same screen instance from before you subscribed won't retroactively re-render unless it was already listening — which job detail and messaging screens now are, so this should not happen; if it does, note it and move on, don't debug live).
