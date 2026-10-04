# Marketplace and business directory: manual click-test checklist

Run against a **demo database** (not the live project) with every migration up to `20261003170000` applied and the seeds loaded. Use a phone-width window (about 390 px) and also a narrow one (320 px). You need three people: a visitor (`ahmad.ramadhan@example.com`), a business owner (any seeded alumnus, for example `bunga.ayu@example.com`) and an admin (a row in `app_admins`, see `20261003130000_app_admins.sql`). Tick the box when it behaves as written.

## Every role: things that must always be true
- [ ] Every marketplace screen shows a short notice that payment is between buyer and seller and that nothing is paid in the app.
- [ ] No screen mentions a subscription, a fee or a commission.
- [ ] Prices look like `Rp 1.500.000`.
- [ ] No yellow and black overflow stripes on any screen.
- [ ] The **BETA** label shows in Profile > About.

## Visitor
- [ ] **Market > Products** shows live products. The 12 old seed listings (no business) are still visible as legacy listings.
- [ ] Search, category chips and sort work. A nonsense search shows an empty message.
- [ ] Product detail shows photo, price, category, city, business and seller.
- [ ] **Market > Businesses** lists only approved businesses. Search and band filter work.
- [ ] A business page shows its band label (for example "Usaha mikro") and its products.
- [ ] **Request contact** on a product or business sends a request. A second tap says it is already sent.
- [ ] **...** menu: Report needs a reason; the same item cannot be reported twice by the same person. Block hides that person everywhere. Profile > Blocked users unblocks.
- [ ] There is no Chat tab and no "Message" button.
- [ ] There is no "Add a product" button without an approved business.

## Business owner
- [ ] **Profile > My business > Register a business**: empty submit shows errors; links must be https; Yearly sales needs a band. After submit the status is **Pending** and the message says an admin must approve it.
- [ ] A person with several businesses sees all of them. Another person cannot see or edit them.
- [ ] After approval the owner gets a notification (bell on Home).
- [ ] **Add a product** is only offered for approved businesses. It goes live at once (no review queue).
- [ ] The free limit by band is shown: micro, small and medium 3 products, large 1. Marking a product sold frees a slot.
- [ ] At the limit, a clear message appears and the form does not submit. No payment screen exists.
- [ ] After `unlimited_until` is set in the dashboard, posting works with no limit and Home shows the days left. After it expires, old products stay visible and only new ones are blocked.
- [ ] Edit, mark as sold and delete (with a confirm) work on own products only.
- [ ] A suspended business hides its products and cannot add new ones.
- [ ] Requests: accept shares the contact, decline does not. The requester is notified.

## Admin
- [ ] **Profile > Admin** shows only for admins. No passphrase is asked.
- [ ] Businesses: approve, reject (reason required) and suspend work and notify the owner.
- [ ] Reports: lists reports with the reason; an admin can hide or reject the product.
- [ ] Marketplace review still lists reported items; reject needs a reason.
- [ ] Feedback: lists new feedback newest first; mark as seen or done.

## Cross-role flow (end to end)
- [ ] Owner registers a business -> admin approves -> business is in the directory -> owner posts a product -> visitor sees it -> visitor requests contact -> owner accepts -> visitor reports it -> admin sees the report -> admin hides it -> it leaves Market.
- [ ] Admin suspends the business -> its products vanish; approve again -> they return.

## Regression
- [ ] Verification, PIN lock, Profile, Directory, Nearby (map follows dark mode), Jobs (list, post, apply, no subscriber gate), News.

## Known gaps to keep in mind while testing
- Roles are not enforced by real login (see README "Closed beta warning").
- Seed images come from picsum.photos: if they show a grey icon, check the network.
