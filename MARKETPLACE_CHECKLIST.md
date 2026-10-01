# Marketplace demo: manual click-test checklist

Run against the **demo database** (not the shared live project), with the
marketplace migrations and both seeds applied. Use a phone-width window
(about 390 px) and also try a narrow one (320 px).

Accounts (see `supabase/seed.sql`): free user `ahmad.ramadhan@example.com`,
subscriber `bunga.ayu@example.com`, admin `farrel.abi.saleh@gmail.com`.
Tick the box when it behaves as written.

## Every role: things that must always be true
- [ ] A "Demo only, no real payments" banner is visible on: Marketplace,
      listing detail, Post/Edit listing, My listings, Admin review (both tabs).
- [ ] No screen mentions a fee, commission or cost of selling.
- [ ] Prices look like `Rp 1.500.000`.
- [ ] No yellow/black overflow stripes on any screen.

## Free user (ahmad.ramadhan@example.com)
- [ ] Marketplace (Home tile) shows 10 approved listings; the 2 pending ones are NOT there.
- [ ] Search "kopi" narrows by title. Clearing it restores the list.
- [ ] Category chips filter (scroll the chip row sideways). "All" resets.
- [ ] Sort: Newest, Price low to high, Price high to low reorder the list.
- [ ] Nonsense search shows "No listings match these filters."
- [ ] Open a listing: photo, price, category, city, posted date, description.
- [ ] Seller card shows name, major, faculty, class year; tapping opens the
      seller's profile.
- [ ] "Visit shop" appears only if the listing has a shop link and opens it.
- [ ] "Contact seller" appears only if there is contact info and reveals it.
- [ ] Tap "Post a listing": a "Subscribers only" dialog appears (no form).
- [ ] "Not now" closes it. "Subscribe" opens the existing Subscribe screen
      with its pricing text unchanged.
- [ ] No "Admin review" icon in the Marketplace app bar.
- [ ] Report listing: pick nothing and Send -> "Pick a reason". Pick a
      reason, add a note, Send -> confirmation. Report the same listing
      again -> "You already reported this listing."
- [ ] My listings (box icon) is empty with a helpful message.

## Subscriber / seller (bunga.ayu@example.com)
- [ ] "Post a listing" opens the form directly (no dialog). City is prefilled.
- [ ] Submit empty: errors on title, description, price, category, photo, and
      "Add a shop link or contact info (at least one)".
- [ ] Price field accepts digits only.
- [ ] Bad shop link ("abc", "javascript:x") is rejected; a valid https link works.
- [ ] Typing contact info shows "Your contact info will be visible to other members."
- [ ] Pick a photo (JPG/PNG/WebP). A .gif or a file over 2 MB is refused.
- [ ] Submit: message says it will appear once an admin approves it. The
      listing is NOT in Market, but IS in My listings as "Pending review".
- [ ] Edit a pending listing: saved, still pending.
- [ ] Edit an approved listing: form warns it goes back to review; after
      saving it is "Pending review" and disappears from Market.
- [ ] A rejected listing shows "Rejected: <reason>" and an Edit button;
      saving resubmits it as pending.
- [ ] "Mark as sold" (approved only) asks first, then the listing leaves Market
      and shows "Sold" (no Edit button on sold).
- [ ] Delete asks first; Cancel keeps it; Delete removes it.

## Admin (farrel.abi.saleh@gmail.com)
- [ ] An "Admin review" icon shows in the Marketplace app bar. Tapping it asks for the admin passphrase (set with `marketplace_set_admin_key`); a wrong one is refused, the right one opens the queue.
- [ ] Review queue lists pending listings (seed has 2) with seller name,
      description, shop link and contact.
- [ ] Approve: listing leaves the queue and appears in Market.
- [ ] Reject: dialog will not accept an empty reason; with a reason the
      listing leaves the queue and the seller sees the reason in My listings.
- [ ] Reports tab shows a count per reported listing (report one as the free
      user first). A deleted or non-approved listing shows "Listing no longer available".

## Cross-role flow (end to end)
- [ ] Subscriber posts -> admin sees it in the queue -> admin approves ->
      free user sees it in Market -> free user reports it -> admin sees "1 report".
- [ ] Subscriber edits the approved listing -> it vanishes from Market ->
      admin approves again -> it returns.

## Regression: untouched features still work
- [ ] Verification/login, Profile, Alumni directory (search and filters),
      Nearby Alumni, Jobs (list, post, apply), Chat, News.
- [ ] The five original bottom-nav tabs still work; "Market" is the 6th.

## Known gaps to keep in mind while testing
- Roles are not enforced by real login (see README "Known gaps").
- Seed images come from picsum.photos: if they show a grey icon, check the
  network / that host.
