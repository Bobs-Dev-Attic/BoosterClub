# Changelog

Version shown in-app (nav footer) as `AppConfig.appVersion`, kept in step with
`pubspec.yaml`. Bumped on each iteration.

## 1.18.7
- **CI: fixed a flaky security-rules test.** The "only manage_users may change
  another user role" emulator test used `updateDoc`, which additionally requires
  the just-seeded target document to already be visible; under the emulator that
  read could intermittently `NOT_FOUND` and fail the deploy-gating job. Switched
  it to `setDoc(merge)` so it tests the write *rule* only. (Ships the 1.18.6
  committee/teams changes, whose deploy was blocked by this flake.)

## 1.18.6
- **Committee membership moved to a join table; committee Roles; new Teams.**
  Reworked how people relate to committees, and added Teams:
  - **Committee membership is now a separate `committee_members` collection**
    (the source of truth) instead of a list of committee ids stored on each user
    profile. A user can belong to many committees, and each membership carries
    the committee role(s) they hold.
  - **Committees now define their own Roles** (created per committee) that are
    assigned to real app users. The public "Leadership & Committees" page shows
    each role with the member(s) who fill it, and lists unfilled roles as OPEN in
    the "Open roles" call-out — replacing the old typed-in position roster.
  - **New `teams` + `team_members` collections** — a lighter people-grouping. One
    or more users can be a member of a team.
  - **Dedicated management UI**: Admin → Committees gains a per-committee
    *Members* manager (add/remove users, tick their roles); a new **Teams**
    section (under Organization) manages teams and their members. Per-user
    committee checkboxes were removed from Users & Roles.
  - Account page now shows "My Committees & Teams" (with role names) read from the
    join tables. Firestore rules added for the three new collections (public
    committee roster; sign-in-gated teams; manager-only writes), covered by new
    emulator rules tests.

## 1.18.5
- **Admin Dashboard reorganized into categories with flyout menus.** The single
  long row of section tabs (Events, Volunteering, Sponsors, …) is now grouped
  into three flyout menus — **Content & Engagement** (Events, Volunteering, FAQ,
  Gallery, History), **Fundraising & Finance** (Sponsors, Funding, Fundraisers,
  Fundraising, Donations) and **Organization** (Meetings, Committees, Legal,
  Users & Roles, Audit Log). Tapping a category opens a menu of its related
  sections; the active category is highlighted, the current section is ticked in
  the menu and named in a breadcrumb below. Categories and their items still
  respect each manager's permissions, so only accessible sections appear.

## 1.18.4
- **FAQ page content.** Replaced the placeholder FAQs with the Booster Club's
  real questions and answers — what the club is, how it raises money (membership,
  fundraisers, school store & concessions), why to get involved, how clubs & teams
  request funding, and examples of the groups supported. Added an
  `info@wjboosterclub.org` contact prompt to the page header.

## 1.18.3
- **Security tests in CI** (repo review item #5). Added automated tests that
  guard the authorization model so a future change can't silently open up PII
  or privilege escalation:
  - **Firestore & Storage security-rules tests** (`firestore-tests/`, 17 cases)
    run against the Firebase emulators — covering role/grant permissions,
    self-promotion/committee-self-assignment guards, funding-request privacy and
    its manager-only PII subdoc, gallery public/hidden visibility and list
    filtering, gallery upload gating, funding-photo read privacy, the
    locked-down `qr_sessions` shape, and the server-controlled donation ledger.
  - **Cloud Functions unit tests** for the QR helpers (secret hashing, TTL/expiry,
    constant-time secret comparison), extracted into `functions/lib/qr.js`.
  - A new **`security-tests` CI job** runs both on every PR and push, and the
    deploy job now depends on it — so nothing ships if a rule regresses.

## 1.18.2
- **Security: gallery & upload hardening** (repo review items #3 and #4).
  - **Uploads restricted** (item #3): gallery image uploads now require a
    gallery-manager base role (Contributor/Administrator/Web Admin) instead of
    any signed-in user, so a random account can't drop a public-URL image into
    the bucket. Funding-photo reads now require sign-in (funding requests aren't
    public), matching item #2.
  - **Hidden gallery images are now private at the API** (item #4): previously
    a "hidden" image was only filtered in the UI but its Firestore document was
    still world-readable. The gallery read rule now returns only `public == true`
    images to non-managers; the public Gallery page queries public images
    server-side. Legacy images created before the visibility flag existed are
    automatically backfilled to public the first time a manager opens the
    Gallery admin.

## 1.18.1
- **Security: funding requests are no longer publicly readable** (repo review
  item #2). The `funding_requests` collection was world-readable, exposing
  applicant PII (coach/parent emails & names, application history) to anyone.
  Now:
  - The summary is readable only by **signed-in** users (the public Funding page
    shows a sign-in prompt to guests); it no longer contains any contact PII.
  - Contact PII moves to a **manager-only** private subdocument
    (`funding_requests/{id}/private/detail`), readable only with
    `manage_funding`. The submitting member writes it once but can't read
    others'. (A manager-facing in-app viewer for this detail is a follow-up;
    the data was never shown in-app before, so nothing is lost.)

## 1.18.0
- **Security: hardened QR-code sign-in** (repo review item #1). Previously the
  Cloud Function minted a Firebase custom token and wrote it onto the
  `qr_sessions` document, which is publicly readable — anyone who learned a
  session id during the ~5-minute window could read the token and sign in as the
  approving user, or delete sessions to disrupt sign-in. Redesigned so the token
  is never stored in Firestore:
  - The web browser generates a high-entropy secret and stores only its SHA-256
    hash on the session; the secret is never in the QR code or the document.
  - `approveQrSignIn` (phone) now records only the approving uid.
  - A new `claimQrSignIn` function verifies the secret, mints the token, returns
    it directly (never persisted), and deletes the single-use session.
  - `qr_sessions` rules now allow only a locked-down create (with a `secretHash`)
    and public status polling — client update and delete are denied.
  - (Requires re-deploying Cloud Functions: `firebase deploy --only functions`.)

## 1.17.1
- **Documentation & security review pass** (no feature changes).
  - **README rewritten** to cover everything the app now does: full feature and
    role/permission tables, an architecture walkthrough with a "how data flows"
    primer for new developers, verified install/deploy instructions (including
    the `--pwa-strategy=none` / `--no-tree-shake-icons` build flags and the
    Storage CORS step), a "secrets & PII" section, and versioning notes.
  - **Junior-developer code comments**: a "start here" boot-sequence guide in
    `main.dart`, a step-by-step "adding a new content type" recipe on
    `FirestoreService`, the editor-dialog contract in `content_forms.dart`, a
    security note in `firebase_options.dart` explaining that the Firebase web
    apiKey is a public identifier (not a secret), and an up-to-date folder map
    in `storage.rules`.
  - **Secrets audit**: confirmed no private keys/secrets in the repo — the CI
    deploy key lives in a GitHub Actions secret and PayPal credentials in Cloud
    Functions secrets; demo data uses fictional 555 phone numbers and
    example.com emails.
  - **Privacy Policy starter updated** for features added since it was written:
    fundraising order information (name/contact/delivery address, staff-only),
    public committee & leadership rosters, gallery visibility, and the US
    Census geocoding lookup for event addresses. Terms of Use sign-in list
    completed (password, email link, QR, Google/Facebook). *If you already
    published these documents, review and re-publish them from Admin → Legal.*

## 1.17.0
- **Committee positions, leadership groups & member memberships.**
  - Each committee (or new **leadership group**) can now list **positions** —
    a title and who holds it (e.g. "Chair — Dawn Harris", "Commissioner
    (Sports) — OPEN"). Managed in the committee editor ("Title | Person" lines).
  - A committee can be marked as a **Leadership** group (Executive Committee,
    Class Chairs), shown in a dedicated Leadership area on the renamed
    **Leadership & Committees** page, with an **Open positions** call-out
    highlighting unfilled roles. Seeded from the WJ leadership chart.
  - A member can now **belong to one or more committees**. Web Admins assign
    memberships in Admin → Users & Roles (audit-logged); members see their
    committees on their account page. Members can't change their own
    memberships.

## 1.16.0
- **New Committees section.** A public **Committees** page (in the main nav)
  lists the club's standing committees — Concessions, School Store, Mulch Sale,
  Used Book Sale, and any you add — each with its schedule, team roles, detail
  sub-sections, an emphasized call-out, and a "Questions?" contact email.
  Managed in **Admin → Committees** (new `manage_committees` permission), with a
  starter set seeded from the WJ committee flyers.

## 1.15.1
- **Fundraising vendors.** You can now keep a reusable list of vendors/suppliers
  (Admin → Fundraising → **Vendors**) and assign **one or more vendors to each
  product/item** from the item editor. Assigned vendors show under the item in a
  campaign, and the same vendor can be reused across products and campaigns.
  Vendors are managed by Fundraising Admins and readable by fundraising staff.

## 1.15.0
- **New Fundraising module (Admin → Fundraising).** A logistics-focused system
  for running product sales (mulch, t-shirts), raffles and similar campaigns —
  separate from the simple donation-goal "Fundraisers".
  - **Campaigns** with a type, description, fundraising goal, start/end dates,
    vendor/supplier info, and a **workflow** that moves through Planning →
    Selling → Ordering → Delivery → Closed.
  - **Products/items** per campaign with price, optional variants (e.g. t-shirt
    sizes) and a target quantity.
  - **Customer orders** with line items, delivery/pickup address, an assigned
    volunteer, **payment status** (Unpaid/Paid/Refunded) and **fulfillment
    status** (Pending/Packed/Delivered/Canceled), each changeable inline.
  - A **dashboard** per campaign: orders, units, collected vs outstanding,
    to-deliver vs delivered, and progress toward goal.
- **Four new roles** for fundraising: **Fundraising Admin** (full control of the
  module), **Fundraising Volunteer** (add orders and update
  payment/fulfillment/delivery), **Fundraising Vendor** and **Fundraising
  Sponsor** (scoped view permissions). All are assignable in Admin → Users &
  Roles. (Dedicated self-service portal pages for volunteers/vendors/sponsors
  are planned for a later pass.)
- Fixed a demo-mode data bug where a second live view of the same collection
  (e.g. a detail screen) never received its initial snapshot.

## 1.14.4
- **Added a welcome / call-to-action intro to the Volunteering page.** A
  friendly banner above the opportunities invites parents to get involved
  ("Show Your Walter Johnson Pride! VOLUNTEER for Boosters!"), explains that
  roles fit any schedule/location/skill set and that everyone is welcome.

## 1.14.3
- **Gallery images can be marked public or hidden.** The image editor now has a
  **"Show on public gallery"** toggle, so a Contributor can keep an image in the
  library for reuse without showing it on the public Gallery page. Hidden images
  are marked with a **"Hidden"** badge in the Admin grid (and a visibility line
  in the full-screen viewer) and are filtered out of the public Gallery. Images
  created before this flag existed stay public by default. (Visibility is
  enforced on the public Gallery page; it is not a hard access control on the
  raw image file.)

## 1.14.2
- **Fixed Storage images showing as broken images on the web.** Gallery
  thumbnails (and any other Cloud Storage image, e.g. sponsor logos) rendered
  as the broken-image placeholder because the `*.firebasestorage.app` bucket
  had no CORS policy. Flutter web draws images with CanvasKit, which fetches
  the bytes over HTTP and needs `Access-Control-Allow-Origin`; without it the
  browser blocks the fetch. Added a `cors.json` (allow `GET`/`HEAD` from any
  origin — these images are already public) and a deploy step that applies it
  to the bucket with `gcloud storage buckets update`, so images load on the
  web app.

## 1.14.1
- **Fixed the blank grey Gallery admin view.** The Gallery management toolbar
  placed a `Spacer` inside a `Wrap`, which is only valid inside a Row/Column.
  It compiled and analyzed cleanly but threw at layout time in the browser, so
  the whole grid rendered as an empty grey error box and images never appeared.
  Restructured the toolbar (Row with an `Expanded` wrap of view controls on the
  left and the selection/Add-new actions on the right) so it lays out correctly.
  Added a widget test that renders `GalleryAdmin` to guard against a regression.
- **Stop stale caching between deploys.** The web app was built with Flutter's
  default offline service worker, which cached the whole app in Cache Storage
  and served it on the next visit regardless of the (already no-cache) Hosting
  headers — so new deploys only appeared after a hard refresh. The app now
  builds with `--pwa-strategy=none` (no service worker), and `index.html`
  proactively unregisters any previously-installed worker and clears its caches,
  so returning visitors converge on fresh builds automatically. (Trade-off:
  the app no longer works offline, which it never usefully did — every screen
  needs live Firebase data anyway.)

## 1.14.0
- **Revamped Gallery management (Admin → Gallery).** The management view is now a
  **thumbnail grid** with a toolbar (on the "Add new" row) for **sorting**
  (newest/oldest, title, file size), **grid columns** (Auto or 2–6) and
  **thumbnail size** (S/M/L).
  - **Multi-select delete**: tap the corner checkbox on any thumbnails and
    **Delete (N)** removes them in one go.
  - **Full-screen viewer**: tap an image to open it large, swipe or use the
    **prev/next** arrows to navigate, pinch/scroll to **zoom**, and see its
    **metadata** (filename, dimensions, size, created date) plus title, caption
    and tags. From the viewer you can **Download**, **Edit** (title/caption/tags)
    or **Delete**.
- Gallery images now store their **filename, dimensions and size** at upload time
  so the viewer can show them.
- **Gallery upload details.** After choosing an image in the Gallery editor, its
  **pixel dimensions and file size (MB)** are shown, with a warning if it exceeds
  the **10 MB** upload limit (and the save is blocked in that case) — so oversized
  images are caught before a failed upload.
- **Event location quick actions.** The event detail dialog's location row now has
  a **copy-to-clipboard** button (with a check-mark confirmation) and, when the
  location looks like an address (or has map coordinates), an **open-in-Maps**
  button. Replaces the separate "View on map" button.

## 1.13.2
- **Fix blank text on some networks.** The app previously loaded its fonts
  (Inter/Poppins via Google Fonts) **over the network at runtime**, which on
  Flutter web renders text **blank** when the font download is blocked (VPN,
  content blocker, private DNS, or restrictive networks) — leaving the home hero,
  app-bar title, and section headers empty. The app now uses Flutter's
  **bundled default font**, so text always renders regardless of network. Removed
  the `google_fonts` dependency.
- **Show the app version on the loading splash.** The initial "Loading…" screen
  now displays the version (e.g. `v1.13.1`), read from `version.json` so it stays
  in sync with the pubspec version automatically.

## 1.13.0
- **Terms of Use & Privacy Policy.** Added public **/terms** and **/privacy**
  pages (linked from the nav footers) that render editable legal documents, with
  solid **starter drafts** covering the basics — intended as a starting point for
  an attorney to review (bracketed `[PLACEHOLDERS]` mark what to complete).
- **New "Policy Admin" role.** A dedicated role whose only permission is the new
  **`manage_legal`** — it can edit the Terms and Privacy documents (Admin →
  Legal) but nothing else. Administrators and Web Admins can manage them too.
  Legal documents live in a new `legal_documents` Firestore collection (public
  read, `manage_legal` write). The editor supports light markup
  (`#`/`##` headings, `-` bullets, `**bold**`/`_italic_`).
- **Address geocoding fix.** The "Find coordinates" lookup now uses the Census
  **one-line** geocoder endpoint, so typing a full address into the Street field
  (e.g. `6400 Rock Spring Drive, Bethesda, MD 20814`) resolves correctly — the
  previous structured endpoint required the street line only and returned no
  match otherwise.
- **Event addresses are saved.** The street, city, state and ZIP entered in the
  address dialog are now stored on the event and **pre-fill the dialog** the next
  time you edit it.

## 1.12.1
- **Look up event coordinates from an address.** The event editor's **Location**
  field is renamed **Location Address** and gains a **📍 button** that opens an
  address dialog (street, city, state, ZIP). On lookup, the address is geocoded
  via the free **U.S. Census** geocoder (no API key) to auto-fill the
  **Geolocation** latitude/longitude — with a fallback to use the typed address
  without coordinates when there's no match (e.g. non-US addresses).

## 1.12.0
- **Event geolocation.** Events can now carry optional **map coordinates**
  (latitude, longitude) alongside the free-text location. When set, the event
  detail dialog shows a **View on map** button that opens Google Maps.
- **Optional event time.** The Start/End **Time** field now has a **"— blank —"**
  option. Leaving the start time blank marks the event **all-day**, and times
  are hidden for it throughout the calendar, list and detail views.
- **New Gallery (shared media library).** A new **Gallery** section
  (public page + Admin tab) where **Contributors** and content managers upload
  and manage **images** — with titles, captions and tags — that can be reused in
  various parts of the site. Backed by a new `gallery` Firestore collection and
  `gallery/` Storage folder, gated by a new **`manage_gallery`** permission
  (granted to Contributors, Administrators and Web Admins).
- **Home layout**: on wide screens, **"This Day in Wildcat History"** now sits
  **beside** the "Go Wildcats!" hero (filling the space to its right) and
  matches its height; it stacks below the hero on narrow screens.
- The history card gains a **faded, right-aligned Wildcat crest** watermark
  (green-tinted so it reads in both light and dark themes).

## 1.10.1
- **History facts can link to a source.** Added an optional **Source / more info
  URL** to history facts (both the admin editor and the home-page Manage dialog,
  validated as an http/https URL). The "This Day in Wildcat History" card shows a
  **Learn more** link when a source is set; "On This Day" suggestions and the
  local pack pre-fill it with their Wikipedia source.

## 1.10.0
- **Fix missing Admin Dashboard icons** (Users & Roles, Audit Log, Import CSV).
  The web build now ships the full Material icon font (`--no-tree-shake-icons`)
  so no glyph can go blank after an update from a stale cached icon subset.
- **New History Facts admin section** (Admin → History, needs `manage_history`):
  add / edit / delete "This Day in Wildcat History" facts in one place.
- **Built-in local history pack**: one-click import of curated, real Bethesda /
  Montgomery County / Walter Johnson facts — so there's local content even
  before anyone adds their own.
- **"On This Day" external suggestions**: fetch general (Wikipedia-derived)
  history for any date from a public feed, with a **Maryland / Montgomery County
  only** filter, and turn a suggestion into a local fact. (There is no dedicated
  hyperlocal Bethesda/WJ history API; this is an assist for curation.)

## 1.9.0
- **Donations via PayPal, recorded in Firestore.** The Donate button now writes
  a **pending** donation to a new `donations` collection, then sends the donor to
  **PayPal** to pay. A trusted **Cloud Function** captures the payment and a
  **PayPal webhook** (verified server-side) is the source of truth that flips the
  record to **completed** — the client can never mark a donation paid.
  - New `createPayPalOrder`, `capturePayPalOrder`, and `paypalWebhook` Cloud
    Functions (also handle refunds/reversals).
  - New **Donations** admin tab (gated by a new `manage_donations` permission)
    showing every donation, its status, and total raised.
  - Firestore rules only allow the client to create a *pending* record for
    itself; status/capture id are Admin-SDK-only.
  - **Demo mode** simulates the whole handshake so the flow is fully previewable
    without a live PayPal account. Set `PAYPAL_CLIENT_ID` (build) + the
    `PAYPAL_SECRET` / `PAYPAL_WEBHOOK_ID` function secrets to go live.

## 1.8.1
- **Corporate Sponsorship page** rewritten to match the real program: a single
  **one-year stadium banner** sponsorship (**$1,000/yr**). Adds the value-prop
  banner ("Support WJ Boosters and Advertise Your Business"), a **Banner details**
  card (3½ × 9 ft weather-resistant banner, sponsor-provided graphics, displayed
  on the stadium fence, one-year term, post-payment approval process), and a
  contact card that emails **sponsorship@wjboosterclub.org**. Seed data updated to
  the single corporate tier.

## 1.8.0
- **Role-based permissions & delegation.** Access is now governed by granular
  permissions per site area (events, volunteering, sponsors, fundraisers,
  meetings, FAQ, funding, history, seeding, users). A base role grants defaults;
  a **Web Admin** can also **delegate** individual permissions to any user, with
  an **optional expiry** (temporary access).
- New **Users & Roles** admin tab (Web Admin) to set roles and grants; the admin
  dashboard now shows only the sections a user may manage.
- **Audit log**: every role/permission change is recorded in Firestore
  (`audit_log`) and viewable in a new Audit Log tab.
- Firestore rules rewritten to enforce permissions + active (non-expired) grants.

## 1.7.0
- **Light / Dark / Auto theme toggle** at the bottom of the navigation
  (persisted on-device).
- **Event CSV import** (Admin → Events → Import CSV): upload a .csv, map columns
  to event fields, choose duplicate handling (Update / Replace / Skip / Allow),
  then run the import and see a per-row log and summary report.

## 1.6.0
- Left nav item renamed to **Funding Request**.
- **Events** are now clickable — a detail dialog with **Share**, **Facebook/X**
  post links, and an **Add reminder** (Google Calendar) button.
- Added a scrollable **3-month calendar** (arrows to move) that dots event days
  by category; tapping a day lists its events.
- Added **category filters** (Athletics, Arts, Fundraiser, Meeting, Volunteer,
  Deadline, School Holiday, Half Day…); events gain a category (admin-selectable).
- Home page shows **"This Day in Wildcat History"** — facts that Contributors
  (and admins) can add/edit/delete via a Manage dialog. New `history_facts`
  collection + rules.

## 1.5.0
- Rebuilt the **Funding Request form** (full-screen) with the full application:
  Sport Team vs Club selector; team/club name; coach/sponsor name & email;
  parent commissioner name & email; number of student participants; requested
  amount; how funds will be used; met-with-AD/Asst.-Principal yes/no; previous
  request history; current Booster-member parents; and a "contribution to
  fundraising" check-all list. Optional photo (library/camera) retained.
- Request cards now show group type and student count; the extra fields are
  stored and preserved when an admin edits a request.

## 1.4.1
- Point the hero background at `assets/images/wj-frontb.jpg` (the school photo
  filename). Add the file at that path to show the building behind the hero.

## 1.4.0
- Fix stale-asset caching: all files now revalidate (no-cache) except versioned
  canvaskit, so new icon fonts / logos show up immediately after a deploy. This
  fixes the invisible "Post minutes" button icon.
- Home hero adds a **Funding Request** button that opens the Funding page.
- Funding request form lets you attach a **photo** — choose from the library or
  **take one with the camera** (image_picker). Photos upload to Storage and show
  on the request card. Storage rules allow signed-in members to upload funding
  images; contributors can now also submit funding requests.

## 1.3.1
- Fix: Contributors got `permission-denied` when posting minutes because the
  Firestore rules only let admins write to `meetings`. Rules now allow the
  Contributor role to create meeting entries (edit/delete stay manager-only).
  Requires deploying `firebase deploy --only firestore:rules`.

## 1.3.0
- Left navigation rail icons now show hover **tooltips**.
- Loading splash shows the **logo** instead of a paw.
- Home hero can show the **school photo** as a faded, green-tinted background
  (drop a JPG at `assets/images/school.jpg`; falls back to the green gradient).
- Donate page adds a **"Powering Student Success"** section listing the
  2026–2027 Booster Club investments (clubs, athletics, school-wide, events).
- New **Contributor** role can **upload meeting-minutes PDFs** (Firebase
  Storage) that get added to the Meetings page; storage security rules added.

## 1.2.2
- CI fix: the v1.2.1 deploy failed because the service account can't deploy
  Firestore rules (403 on serviceusage). Reverted CI to Hosting-only auto-deploy
  (proven working). Rules/functions deploy from CI needs extra IAM roles and can
  be run manually meanwhile.

## 1.2.1
- CI: full auto-deploy on push to `main` (Firebase Hosting + Firestore rules)
  via the Firebase CLI + a `FIREBASE_SERVICE_ACCOUNT` repo secret — no local
  build/deploy commands needed.

## 1.2.0
- Redesigned **My Account** as a tabbed area: **Dashboard** (activity summary,
  quick actions, your interests), **Account** (name, phone, mailing address,
  organization), **Login & Security** (change email, reset password, sign out),
  and **Preferences**.
- **Preferences**: opt in/out of emails and pick interests grouped by Sports,
  Clubs, Fundraising, Volunteering, Events, Meetings — with sub-categories
  (e.g. Sports → Football/Basketball/Golf…, Clubs → Science/Social/Arts…).

## 1.1.1
- Fix Firebase Hosting cache headers: Flutter's entry-point files
  (`flutter_bootstrap.js`, `main.dart.js`, `flutter_service_worker.js`,
  `index.html`) are no longer cached immutably, so deploys are picked up
  immediately instead of serving stale code.

## 1.1.0
- Logo updated to the black line-art Walter Johnson wildcat crest, shown on a
  white circular backdrop so it stays visible in dark mode and on the hero.
- App **version number** now displayed in the navigation footer.

## 1.0.0
- Initial Booster Club app: responsive Flutter web/mobile UI, Firebase Hosting.
- Content: events, volunteering, sponsorships, donations, funding requests,
  fundraisers, meetings & minutes, FAQ.
- Auth: email/password, passwordless email link, QR-code sign-in, Google,
  Facebook; role-based access with an in-app Admin Dashboard.
- Rebranded to Walter Johnson High School Booster Club (Wildcats, kelly green).
- Content seeding, one-time email-link and QR sign-in flows.
- Events: Start Date + End Date with 30-minute AM/PM time pickers.
