# Lingkaran home hub: manual click-test checklist

Run on a real phone (Android and iOS if you can) plus a desktop browser. Use a demo database, never the shared live project. Accounts are in `supabase/seed.sql`: free user `ahmad.ramadhan@example.com`, subscriber `bunga.ayu@example.com`, admin `farrel.abi.saleh@gmail.com` (see the security audit about that address). Tick each box when it behaves as written. Also try a narrow window (320 px wide) and large system text.

## A. New user (first time on this device)
- [ ] App opens on Welcome ("Get Started"), not the lock screen.
- [ ] Verify with a seeded email. A "Set a PIN" screen appears.
- [ ] Enter a PIN twice: lands on Home. "Hello, <first name>" shows.
- [ ] Try 111111 as a PIN: refused. Try two different PINs: "didn't match", starts again.
- [ ] If the phone has fingerprint: a second step offers it. Turning it on asks for one real scan.

## B. Home hub
- [ ] Bottom bar shows exactly Home, Directory, Chat, Profile.
- [ ] Banner shows the latest announcements, changes by itself every few seconds, swipes, dots follow. Tap opens the full text with a back arrow.
- [ ] "See all announcements" opens the News list with a back arrow.
- [ ] Tiles: Jobs, Marketplace, Nearby Alumni open with a back arrow. Directory switches to the Directory tab.
- [ ] Latest: 3 newest jobs and 3 newest listings; each opens its detail screen. No fee wording. The Marketplace screens still show "Demo only, no real payments".
- [ ] Upcoming: Events, Mentoring, Business directory show "Preview" and are muted. Tapping opens a sheet saying it is a preview and not available yet. Nothing else happens.
- [ ] Back button: from Directory, Chat or Profile it returns to Home. From Home it leaves the app.
- [ ] Nothing was lost: Profile (edit, subscribe, sign out), Directory and Nearby (city chat opens from Nearby), Jobs (detail, apply, post, notifications), Chat, Marketplace (detail, post, My listings, report).

## C. Returning user with a PIN
- [ ] Close the app fully and reopen: dark lock screen, "Welcome back, <first name>", masked email like `a***@example.com` (never the full address), PIN pad.
- [ ] Right PIN opens Home.
- [ ] If biometrics are on: the prompt appears by itself; a scan opens the app; cancel or wrong finger leaves the PIN pad.
- [ ] "Not you? Switch account": goes to Welcome; reopening the app shows Welcome (no lock).
- [ ] "Forgot PIN? Verify again": same result.

## D. Returning user without a PIN
- [ ] Verify, tap "Skip for now" on the PIN screen.
- [ ] Close and reopen: lock screen with a "Continue" button and no PIN pad. Continue goes to Verification.

## E. Wrong PIN five times
- [ ] Wrong PIN once: "Wrong PIN. 4 attempts left."
- [ ] Third wrong PIN: a "Try again in Ns" wait; the pad ignores taps during it.
- [ ] Close and reopen during the wait: the attempts count is not reset.
- [ ] Fifth wrong PIN: back to Welcome with "Too many wrong PINs. Please verify again." Reopen: Welcome again.

## F. Background timeout
- [ ] Sign in, leave the app for under 5 minutes, come back: no lock.
- [ ] Leave it for over 5 minutes: the lock screen covers the app; the right PIN returns you to the exact screen you left.
- [ ] While locked, the app content is not visible or tappable.

## G. Admin and non-admin
- [ ] Non-admin (Ahmad): Marketplace has no admin entry. Cannot post (needs to subscribe).
- [ ] Admin: the Marketplace admin icon asks for the admin passphrase (wrong one refused, right one opens the queue); approve and reject (with reason) work. Only after the security migrations and `marketplace_set_admin_key` were run on the demo database.
- [ ] Sign out on the Profile tab, then verify as the other role: the old PIN is gone and you are asked to set a new one.

## H. Empty announcements
- [ ] On a demo database with no announcements: Home shows the static "Welcome to Lingkaran" card, no dots, and "See all announcements" still opens the (empty) News screen.
- [ ] With the network off: the banner shows "Couldn't load announcements." with "Try again"; the Latest blocks show their own "Try again". No raw error text.

## I. Web
- [ ] Every visit starts at Welcome (there is no lock screen on web, by design).
- [ ] No layout overflow at phone width; no yellow/black stripes anywhere.
