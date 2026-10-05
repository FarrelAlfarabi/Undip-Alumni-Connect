# Cookie and Storage Policy (DRAFT)

> Written from the code as of 2026-10-04. Re-check it with the browser test in `docs/LEGAL_AUDIT.md` every time you add a script, embed or package. Not legal advice.

Version 2026-10-04-draft1. Operator: <<REPLACE: operator name>>. Contact: <<REPLACE: contact email>>.

## Short version
Lingkaran does not use advertising, analytics or tracking cookies. It sets no cookies of its own on the web. That is why there is no cookie banner. If we add anything that is not strictly necessary, we will add a consent banner first, before it loads.

## What is stored on your device
| What | Where | Why | How long |
|---|---|---|---|
| PIN (salted hash only), remembered profile id, name, masked email, fingerprint choice | Android or iOS secure storage (not on the public web build) | Lock the app on your phone | Until you sign out of the device, choose Switch account or Forgot PIN, enter 5 wrong PINs, or delete your account |
| Technical sign in data from the database library | Browser storage on web, if any | Needed for the app to talk to the database | Until you clear site data |

These are strictly necessary for the service you asked for, so they need no consent. They are not used for tracking.

## Requests to other companies
When the web app opens, your browser asks Google servers (fonts.googleapis.com, fonts.gstatic.com, www.gstatic.com) for fonts and the drawing engine. Google can see your IP address and browser details. These requests do not set cookies, but they are third party requests. We plan to host these files ourselves so this stops. Product photos may load from other hosts that the seller linked.

## How to control it
Clear site data in your browser settings, or sign out and delete your account in the app. Contact: <<REPLACE: contact email>>.
