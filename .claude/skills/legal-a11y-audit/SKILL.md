---
name: legal-a11y-audit
description: Audit a website or app (especially an AI-built, "vibecoded" one) for legal and accessibility risk and fix what can be fixed in the repo. Covers privacy policy, terms, cookie policy, refund policy, cookie consent, WCAG 2.1 AA (alt text, contrast, keyboard, button labels), third-party scripts and trackers, data minimisation, fake reviews and unsupported claims, image licences, required business details in the footer, country-specific law, and other risks (dark patterns, security.txt). Use this whenever the user says "audit my site so I don't get sued", "do I need a cookie banner", "GDPR / CCPA / DPDP / UU PDP check", "make my privacy policy / terms", "WCAG check", "legal pages for my app", or wants a compliance checklist for a vibecoded site, even if they do not name every item.
---

# Legal and accessibility audit

Goal: read the real code, fix what is safe to fix, and hand back a checklist where every item is marked **[FIXED]** (you changed the repo) or **[NEEDS REVIEW]** (the owner or a lawyer must decide or act). Be honest that this is not legal advice and that nobody can promise "no mistakes" or "no lawsuit". Overclaiming is the main way this kind of audit goes wrong, so every claim in the output must come from something you actually read.

## 0. Set up before you start
1. **Country or state.** If the user left it as a placeholder (for example `[INSERT YOUR COUNTRY/STATE]`), infer it from the repo (language, university, hosting region) and say which country you assumed. Still cover GDPR, CCPA/CPRA and India's DPDP Act 2023 if the user asked for them. Add the local law (see `Local law pointers` below).
2. **What is audited.** Find out what the product is (web app, mobile app, static site), where it is hosted, and what data it holds. Read: entry HTML, host config (headers, CSP), dependency list, theme/colour file, seeds and sample data, existing policy files, build scripts.
3. **Never invent identity.** Operator legal name, physical address, contact email, governing city, security contact: you cannot know these. Put a clearly marked `<<REPLACE: ...>>` (or the project's existing placeholder constant), list every one at the top of the report, and tell the user to replace them before release. A placeholder that looks like real text is worse than an obvious one.
4. **Do not change deployment or hosting** (build scripts, CI, live database) unless the user explicitly says so. Describe the exact change and ask. Do not run anything against a live database.

## 1. Legal pages
Write complete plain-language drafts based on what the code actually does, not on generic boilerplate. Copy and adapt the templates in `references/`. They were written for one project (Lingkaran, an alumni app for FEB UNDIP and Ikafe, run in Indonesia), so replace its names, features, providers and law references with the facts of the project you are auditing:
- `TERMS_AND_CONDITIONS.md`, `COOKIE_AND_STORAGE_POLICY.md`, `REFUND_POLICY.md`.
- Privacy policy: if one already exists in the repo, extend it rather than adding a second one. It must contain: what is collected and why, legal basis, who sees it, service providers and countries where data goes, how long it is kept (only promise retention you actually enforce; say "nothing is deleted automatically" if true), rights (access, correction, deletion, withdraw consent, objection, portability, complaint to the authority), CCPA "we do not sell or share", DPDP/UU PDP grievance contact, children, how to contact. Bump the policy version constant if the app asks users to re-accept.
- Refund policy: if the product takes no payment, do not write a fake one. Write the short "no payments, deals are between users" text and say what to do the day payments start.
- Mark as [NEEDS REVIEW]: a local-language version (for example Bahasa Indonesia for Indonesian users), any response-time promise (for example 30 days), breach-notification plan, data processing agreements with providers.

## 2. Cookie consent
Decide from evidence, not habit. Open `references/consent-banner.html` only if needed.
- Look for: cookies set in code, `localStorage`/`sessionStorage`, analytics, ads, pixels, social embeds, chat widgets, maps, video embeds, fonts and libraries loaded from a CDN.
- A banner is needed when anything non-essential sets cookies or sends visitor data to a third party. If nothing does, say a banner is **not needed**, show the evidence, and still document essential storage.
- Fonts or scripts from Google or other CDNs send the visitor's IP to a third party without cookies. Under GDPR this still counts (a German court, LG München 2022, ordered damages over Google Fonts). Recommend self-hosting; that also removes the need for a banner.
- If a banner is needed, use `references/consent-banner.html`: non-essential scripts are not in the page and are added only after the user clicks Accept; Reject is as easy as Accept; the choice can be changed later.
- Always give the DevTools test: private window, Application > Cookies empty before any click; Network > third-party requests list; after Reject still no analytics request; after Accept the script and cookie appear only then; check Local/Session storage.

## 3. Accessibility (WCAG 2.1 AA)
- Contrast: compute real ratios for brand colours against the backgrounds they are used on (text 4.5:1, large text 3:1, UI parts 3:1). Fix by darkening the offender in one place and add a test that keeps it above the line. Keep a bright variant only for decoration.
- Images: every meaningful image gets a text alternative (for example "Photo of <title>"); decorative ones are hidden from screen readers.
- Keyboard and forms: every control reachable with Tab, visible focus, labels tied to inputs, tap targets at least 48 dp (44 px on web), icon-only buttons have a label or tooltip. Prefer an automated test over eyeballing it (for Flutter: pump each screen at 320 px wide and 1.6x text, check `takeException()`, button sizes and tooltips; load a real font because the default test font is far too wide and gives false overflows).
- Button labels say what they do ("Send feedback", not "Submit" or "OK").
- Canvas-rendered web apps (Flutter, games) show nothing to screen readers until semantics are on; flag it. Check the `lang` attribute and page title.
- Say plainly that you did not test with real assistive technology or devices.

## 4. Data and tracking
List every third-party request and script and what it receives. Flag anything that loads before consent and give an alternative (self-host, remove, or load after consent). Check data minimisation: is each field needed? Look for sensitive data exposed to everyone (ID numbers, emails, CVs in public storage) and flag it [NEEDS REVIEW] with the real fix (login, private storage).

## 5. Content and claims
Search for testimonials, ratings, "best", "#1", "guaranteed", "verified", "official", logos and names of third parties. Remove or soften what cannot be proven (for example "verified" when the check is only an email match). Check image and font licences: your own artwork, stock photos (licence terms, people in photos), open fonts (keep licence text if bundled). Check permission to use any third-party data list (for example a membership list) and names or brands.

## 6. Business details
Add operator name, physical address and contact method where users will see them (footer, About screen, policy header). Use placeholders per step 0.3 and warn: do not release with placeholders in place.

## 7. Local law pointers (verify, do not quote as certain)
- **Indonesia:** UU PDP 27/2022 (grace period ended Oct 2024; breach notice within 3x24 hours; transfers abroad), registration as private electronic system operator (PSE, Permenkominfo 5/2020) which needs a lawyer's answer even for a closed beta, UU ITE, UU 8/1999 consumer protection, PP 80/2019 and Permendag 50/2020 e-commerce, UU 24/2009 Art. 31 language, UU 28/2014 copyright.
- **EU/UK:** GDPR, ePrivacy (cookies and device storage), legal basis, transfers, DPO thresholds.
- **California:** CCPA/CPRA (know, delete, correct, no sale or share, no worse treatment).
- **India:** DPDP Act 2023 (plain-language notice, consent, grievance officer, notice in scheduled languages).
Mark every one [NEEDS REVIEW] unless it is a plain fact about the code.

## 8. Other risks
Dark patterns (pre-ticked boxes, hidden reject, hard cancellation or deletion), no real login (anyone can act as anyone), public file buckets, missing security headers (CSP, HSTS, frame, referrer, permissions), `security.txt` (use `references/security.txt.template`, never publish it with placeholders), no backups, no breach plan, no provider data agreements, no admin audit log.

## Output
Write `docs/LEGAL_AUDIT.md` (or the project's docs folder) with: a short "what this is and is not" paragraph; the country assumed; the list of things to replace; then numbered sections 1 to 8 as a checklist with [FIXED] and [NEEDS REVIEW]. Put drafts in `docs/legal/`. Run the project's analyze and test commands before committing. In your final message to the user: lead with what is fixed, then the decisions only they can make, then what you did not verify. Keep sentences short and plain.
