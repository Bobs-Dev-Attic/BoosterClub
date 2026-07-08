# Changelog

Version shown in-app (nav footer) as `AppConfig.appVersion`, kept in step with
`pubspec.yaml`. Bumped on each iteration.

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
