# Legal and accessibility audit (2026-10-04)

**What this is.** A review of this repo (the Flutter app and its web build on Vercel), by reading code, config and seeds. I did not open the live site, the live database or a lawyer's checklist for your country. It is not legal advice and nobody can promise "no mistakes" or "you will not be sued". [FIXED] means I changed the repo. [NEEDS REVIEW] means you or a lawyer must decide or act.

**Country.** Your message left `[INSERT YOUR COUNTRY/STATE]` empty. I assumed **Indonesia** (UNDIP, Ikafe, Supabase region Singapore) and also covered GDPR, CCPA and India DPDP as you asked. Tell me if the operator is somewhere else.

**Replace before publishing** (I cannot know these): operator legal name, physical address, contact email (`lib/config/policy_config.dart`), governing city in the Terms, security contact and expiry date in `security.txt`.

## 1. Legal pages
- [FIXED] Privacy policy (`assets/policy/privacy_id.md`, `privacy_en.md`) now adds: legal basis, service providers and where data goes (Supabase Singapore, Vercel mostly US, GitHub, Google Fonts), the rights list (access, correction, deletion, withdraw consent, objection, portability, complaint to the authority), CCPA wording (no sale or sharing), DPDP and UU PDP grievance contact, children (18+), retention. Version bumped to `2026-10-04-draft2`, so everyone is asked to accept again.
- [FIXED] Terms and Conditions drafted: `docs/legal/TERMS_AND_CONDITIONS.md`.
- [FIXED] Cookie and storage policy drafted: `docs/legal/COOKIE_AND_STORAGE_POLICY.md`.
- [FIXED] Refund policy: `docs/legal/REFUND_POLICY.md`. There are no payments, so it is a "no refunds from us, deals are between users" text, not a fake full policy.
- [NEEDS REVIEW] Terms and cookie text are not yet inside the app. Put the Terms next to the privacy policy (Profile) and add them to the consent step, then bump `kPolicyVersion` again.
- [NEEDS REVIEW] Indonesian version of the Terms (UU 24/2009 Art. 31 asks for Bahasa Indonesia in agreements with Indonesian parties). The privacy policy already has both languages.
- [NEEDS REVIEW] Retention: only "until you delete your account" is enforced. The policy says honestly that nothing is deleted automatically. If you want inactivity limits, build them first.
- [NEEDS REVIEW] Promise of answering rights requests in 30 days. You must be able to do that, by hand.
- [NEEDS REVIEW] DPDP Act 2023 asks for the notice in plain language and, for Indian users, an option in any of the 22 scheduled languages. Needed only if you have users in India.
- [NEEDS REVIEW] UU PDP 27/2022: breach notification within 3 x 24 hours to users and the authority, and a data protection officer in some cases. You need a written breach plan.

## 2. Cookie consent
- Result: **a cookie banner is not needed today.** The app sets no cookies and has no analytics, ads, pixels or embeds. Only essential device storage (PIN lock, phone only) exists.
- [NEEDS REVIEW] Google Fonts and CanvasKit load from Google (`fonts.googleapis.com`, `fonts.gstatic.com`, `www.gstatic.com`) before any consent. No cookies, but the visitor's IP goes to Google. A German court (LG München, 2022) ordered damages to a visitor for this under GDPR. Fix: bundle the fonts (`google_fonts` supports local font files in `pubspec.yaml`, set `GoogleFonts.config.allowRuntimeFetching = false`) and build web with the CanvasKit files kept (`scripts/vercel-build.sh` deletes `build/web/canvaskit`; remove that line and add `--no-web-resources-cdn`). Then remove the three Google hosts from `vercel.json` CSP. I did not change the build script, because you told me not to change how the web version is deployed. Say so and I will do it.
- If you ever add analytics or an embed, you need a banner that blocks them until consent. Pattern (works for any script): keep the script out of the page, load it only after the click.

```html
<div id="consent" role="dialog" aria-labelledby="consent-title" aria-live="polite" hidden
     style="position:fixed;inset:auto 0 0 0;background:#211D3C;color:#fff;padding:16px;font:16px/1.4 system-ui;z-index:9999">
  <p id="consent-title" style="margin:0 0 12px">We would like to use analytics to improve the app. It is off until you agree.
    <a href="/privacy" style="color:#fff">Privacy policy</a></p>
  <button id="consent-accept" style="min-height:48px;padding:0 20px;font:inherit">Accept analytics</button>
  <button id="consent-reject" style="min-height:48px;padding:0 20px;font:inherit">Reject</button>
</div>
<script>
(function () {
  var KEY = 'consent-analytics';           // 'yes' | 'no'
  var box = document.getElementById('consent');
  function load() {                         // ONLY place a non-essential script is added
    var s = document.createElement('script');
    s.src = 'https://ANALYTICS.EXAMPLE/script.js'; // REPLACE with the real script
    s.async = true; document.head.appendChild(s);
  }
  var v; try { v = localStorage.getItem(KEY); } catch (e) {}
  if (v === 'yes') load(); else if (v !== 'no') box.hidden = false;
  document.getElementById('consent-accept').onclick = function () {
    try { localStorage.setItem(KEY, 'yes'); } catch (e) {} box.hidden = true; load(); };
  document.getElementById('consent-reject').onclick = function () {
    try { localStorage.setItem(KEY, 'no'); } catch (e) {} box.hidden = true; };
})();
</script>
```
  Reject must be as easy as Accept (same size, same level). Also allow people to change their mind later (a "Cookie settings" link that clears the key).
- How to test in Chrome DevTools (do it on the real site now, and after any change):
  1. Open a Private window, open DevTools (F12), tab **Application > Cookies**: the list for your domain must be empty on first load, before any click.
  2. Tab **Network**, tick "Disable cache", reload, filter by "Third-party" (the funnel icon, "3rd-party requests"). Today you will see the Google hosts. After the fix the list must be empty (Supabase API calls are your own backend and belong to the app).
  3. If you added the banner: reload and confirm no request to the analytics host and no new cookie before you click Accept. Click Reject: still none. Click Accept: the script and cookie appear only now.
  4. **Application > Local storage / Session storage**: nothing besides what the cookie policy lists.

## 3. Accessibility (WCAG 2.1 AA)
- [FIXED] Colour contrast: brand brass `0x9C6E22` was 4.06:1 on the page background and 4.16:1 under light button text, 3.61:1 on raised cards. Now `0x7F5815`, 5.09 to 5.87:1 (`lib/theme.dart`). A test keeps it above 4.5:1 (`test/accessibility_test.dart`).
- [FIXED] Alt text: marketplace photos now have a text alternative ("Photo of <title>") in every list, detail, form and admin view. Decorative uses stay hidden from screen readers.
- [FIXED] Buttons and forms: a test over about 25 screens found no tap target under 48 dp and no icon-only button without a label (`test/layout_stress_test.dart`). Forms are standard Flutter text fields, reachable with Tab and Enter. Fixed a case where the consent button could be pushed off screen at very large text.
- [NEEDS REVIEW] Flutter web draws on a canvas. Screen readers see nothing until the hidden "Enable accessibility" button is activated. Call `SemanticsBinding.instance.ensureSemantics()` at start-up for web if you want it always on (slower). Test with NVDA or VoiceOver and a keyboard only.
- [NEEDS REVIEW] Not tested on real devices or with real assistive tech. Some grey helper text and borders use Material's default colours; I did not measure every one.
- [NEEDS REVIEW] The Nearby map is a drawing. Its information is also available as the list view (the toggle beside it), which is the accessible alternative. Check the toggle is easy to find.
- [NEEDS REVIEW] No "skip to content" or language attribute control for the web page: `web/index.html` has no `lang` attribute. Add `<html lang="id">` (or `en`) and a descriptive `<title>`.

## 4. Data and tracking
- Third-party scripts or analytics found in code: **none**. No Firebase, Google Analytics, Sentry, ads or social embeds.
- Third-party requests found: Google Fonts and CanvasKit (above). Product photos may come from any host the seller linked (seed photos come from `picsum.photos`).
- [NEEDS REVIEW] Data minimisation: the directory sends everyone's **email and NIM** to every client, and shows NIM to other alumni. NIM is an ID number. This is the biggest privacy problem in the repo (`SECURITY_AUDIT.md`). Fix needs real login and a view without those columns.
- [NEEDS REVIEW] Product photos and CVs sit in **public** buckets. A CV contains personal data. Needs private buckets and signed links.
- [FIXED] Feedback reports are cleaned of emails, keys, phones and URLs before sending.

## 5. Content and claims
- Fake reviews, testimonials, ratings, "best", "#1", "guaranteed" claims: **none found** in the app code.
- [FIXED] Welcome said "A verified alumni directory". Verification is a match against the Ikafe list, not proof of identity, so it now says "An alumni directory checked against the Ikafe list".
- [NEEDS REVIEW] "Seeded from Ikafe's member base": do you have written permission from Ikafe to use the member list, and did the alumni agree to their data being loaded? Under UU PDP and DPDP, loading people's data without their consent or another legal basis is a risk. Get a data sharing agreement with Ikafe.
- [NEEDS REVIEW] Images: app icons and favicon (`web/icons`, `web/favicon.png`) and the Kawung mark are your own placeholder artwork (confirm you made them or have a licence). Seed marketplace photos come from picsum.photos (Unsplash photographers, free licence, no attribution needed, but random people may appear). Replace with your own or real seller photos before launch. Fonts IBM Plex Sans and Fraunces are SIL Open Font Licence (fine; keep the licence text if you bundle them). Seller photos are the seller's responsibility (Terms section 4), but you need a takedown path: Report in the app plus the contact email.
- [NEEDS REVIEW] `Not UNDIP's or Ikafe's official branding` is shown. Using "UNDIP" and "Ikafe" names and the Kawung motif: get permission or keep the disclaimer.

## 6. Business details
- [FIXED] Profile > About now shows operator name, physical address and contact email (from `lib/config/policy_config.dart`). The privacy policy already shows operator and email.
- [NEEDS REVIEW] They show `[FILL IN: ...]` until you replace the three values. **Do not release before you do.** The web app has no footer, so also put the same lines on the Welcome screen or the Vercel page if you want them visible before sign in.
- [NEEDS REVIEW] Indonesian marketplace rules (PP 80/2019, Permendag 50/2020) expect sellers and the platform to be identifiable. Seller business identity is shown only by name and links today.

## 7. Local laws: Indonesia (assumed)
- UU PDP No. 27/2022 (in force; the two year grace period ended Oct 2024): legal basis, rights, breach notice, possible DPO, rules on transfers abroad (your data is on servers in Singapore, the US). [NEEDS REVIEW] Confirm with a lawyer which implementing rules apply now.
- Registration as a private electronic system operator (PSE Lingkup Privat, Permenkominfo 5/2020 via the OSS/Komdigi portal) is required for services used in Indonesia. [NEEDS REVIEW] Check whether a closed beta is exempt. Do not skip this question.
- UU ITE (information and electronic transactions), UU 8/1999 consumer protection, UU 28/2014 copyright, UU 24/2009 language. [NEEDS REVIEW]
- Tax or business licence if the operator earns money. Not applicable while it is free.
- If you have users in the EU, UK, California or India, the GDPR, UK GDPR, CCPA/CPRA and DPDP Act also apply to them. For a closed Indonesian beta the risk is low, and it grows with public launch.

## 8. Other risks
- [NEEDS REVIEW, High] **No real login.** Anyone who knows an email or profile id can act as that person, admins and account deletion included. Before any public launch: Supabase Auth with email codes.
- [FIXED, template only] `security.txt` template at `docs/legal/security.txt.template`. Put it at `web/.well-known/security.txt` after replacing the contact and expiry. I did not publish it because it needs your real email.
- [FIXED] Security headers already exist in `vercel.json` (CSP, HSTS, frame deny, no sniff, referrer policy, permissions policy). No change.
- Dark patterns: none found. The consent box is unticked, "Continue" stays off until ticked, Back and sign out is always available (a plain text button), and deleting the account is one clear path (type HAPUS). [NEEDS REVIEW] The consent text is long and bundles privacy and community rules in one tick. A lawyer may want separate boxes.
- [NEEDS REVIEW] No backups, no breach plan, no data processing contracts signed with Supabase and Vercel (accept their DPAs in each dashboard).
- [NEEDS REVIEW] Admin power: admins can see reports, feedback and businesses; there is no audit log of what an admin did.
