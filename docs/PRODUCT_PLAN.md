# Lingkaran (UNDIP Alumni Connect): Product and Build Plan (public excerpt)

**Version:** 1.9, 30 September 2026
**Status:** Public, redacted excerpt of an internal planning document. Business terms, finances, legal and partner details are intentionally left out. Dummy data only; no real payments.

## 1. What this is

A mobile and web app for alumni of the Faculty of Economics and Business (FEB), Universitas Diponegoro, built with the alumni association Ikafe.

The core idea is a verified alumni directory connected to an alumni job referral board. WhatsApp groups fade over time and LinkedIn cannot verify alumni by faculty and cohort. Every feature is checked against one question: does it strengthen the directory and referral loop?

## 2. Audience and access

- FEB alumni only.
- Browsing is free. A paid subscription unlocks messaging, contacting job posters and posting in the marketplace.
- Launch is a closed, invite-only beta.

## 3. Features

**Built in the demo:** verified-style profile, searchable directory, job board with search and filters, messaging, announcements, Nearby Alumni (by city), simulated notifications and email, a visual subscription paywall.

**Planned:**

| Feature | Notes |
|---|---|
| Marketplace (demo built, on a feature branch, not merged) | Alumni to alumni. Listings appear only after admin approval. Each listing links to the seller's online shop and/or shows contact info. Subscribers post; everyone browses. Demo only: no checkout, no payments. |
| Home hub | Dashboard home with a banner carousel (from announcements), quick-action tiles (Jobs, Marketplace, Directory, Nearby Alumni) and a "latest" strip. Bottom navigation reduced to about four items. Also shows non-functional "Preview" tiles (Events, Mentoring, Business directory) for upcoming features. |
| Returning-user lock screen | Users already verified on a device see "Welcome back", a 6-digit PIN pad and optional biometrics instead of the full login. PIN stored only as a salted hash in secure storage; 5 wrong attempts forces full verification. On the demo auth model this is a convenience lock, not server-side security. |
| AI job-description drafting | Suggests a job description when posting a job. Called through a server function so no API key is in the app. Must never block posting if it fails. |
| Real verification and payments | Not started; depend on external data access and provider decisions. |

**Deliberately cut for now:** open forums, social feed, mentorship matching, events board. They need moderation or content supply a solo builder cannot provide.

## 4. Technical overview

- **Frontend:** Flutter (Android, iOS, web from one codebase).
- **Backend:** Supabase (Postgres, Auth, Storage, Edge Functions, row-level security).
- **AI:** provider-agnostic interface behind an Edge Function; API key held as a server secret.
- **Hosting:** web build on Vercel.

## 5. Build approach

- Staged work, one commit per stage, manual review between stages.
- Feature branches; changes to the shared live database are never applied from a feature branch. Demos run against a separate database.
- Each stage runs static analysis, tests, database-rule checks and a web build; failures are fixed and re-run before a commit.
- Marketplace demo: built in stages (data layer, browse and detail, create and subscriber gate, admin approval and reporting, polish and regression).
- Next: home hub, Preview tiles and returning-user lock screen, in staged prompts.
- Before any real user data is loaded: a security and privacy audit against the OWASP checklist, reported first and fixed in reviewed steps.

## 6. Known technical gaps

- Demo has no real per-user authentication; row-level security cannot enforce per-user access on the demo branch.
- Production hardening (real auth, tightened policies) exists on a separate branch and is not merged. Some tables with personal data still need policies tightened.
- Messaging has no realtime updates on the demo branch.
- Nearby Alumni needs a safety design (granularity, opt-in default, retention) before production.
- Store review needs report and block functions for user-generated content, in-app account deletion and accurate privacy labels.
