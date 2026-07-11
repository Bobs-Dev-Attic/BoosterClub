# 🦁 WJ Booster Club

A responsive **Flutter** web & mobile app for a High School Booster Club, hosted on
**Firebase Hosting** with **Firebase Auth**, **Cloud Firestore**, and **Cloud Storage**.

Members, supporters, sponsors and administrators can browse and manage school events,
volunteering, committees & leadership, sponsorships, donations, funding requests,
fundraising campaigns (mulch/t-shirt/raffle logistics), meetings & minutes, a shared
photo gallery, and an FAQ.

The UI is fully responsive — a navigation rail on desktop/laptop browsers and a
drawer + bottom navigation on phones.

---

## ✨ Features

| Area | What you get |
| --- | --- |
| **Content** | Events (with geocoded locations & map links), Volunteering, Committees & Leadership, Sponsorships, Donations (PayPal), Funding Requests, Fundraisers, Meetings & Minutes, Gallery, FAQ, Terms & Privacy pages |
| **Fundraising module** | Campaigns with a workflow (Planning → Selling → Ordering → Delivery → Closed), products/items with variants and vendors, customer orders tracked through payment & delivery, and a per-campaign dashboard |
| **Auth** | Email/Password, one-time email link (passwordless), QR-code sign-in, Google, Facebook, password reset |
| **Roles** | Guest → Supporter → Member → Contributor → Sponsor → Fundraising (Vendor/Sponsor/Volunteer/Admin) → Policy Admin → Administrator → Web Admin |
| **Permissions** | Every admin area is gated by a granular permission; Web Admins can also *delegate* individual permissions to any user, optionally with an expiry. All changes are audit-logged |
| **Committees** | Public "Leadership & Committees" directory (positions & who holds them, OPEN roles); members can belong to one or more committees |
| **Gallery** | Contributor-managed image library: thumbnail grid, sorting/sizing, multi-select delete, full-screen viewer with metadata, public/hidden visibility per image |
| **Responsive** | Looks good on any phone and on a desktop/laptop browser |
| **Demo mode** | Runs with seeded sample data until Firebase is configured, so you can preview instantly |

## 🏗️ Architecture

The app is a classic three-layer Flutter design. If you're new to the codebase, read it
in this order:

```
lib/
  main.dart                  App entry point: initializes Firebase (or falls back to
                             demo mode), then hands off to the router.
  config/app_config.dart     App name, version, demo-mode flag, PayPal client id.
  firebase_options.dart      Firebase project identifiers (see "About secrets" below).
  router/app_router.dart     All URL routes (go_router) inside a responsive shell.
  theme/app_theme.dart       Material 3 theme (school colors, light/dark).

  models/                    Plain-Dart data classes. Each knows how to read itself
                             from a Firestore document (fromDoc/fromMap) and write
                             itself back (toMap). No UI code here.
    app_user.dart            AppUser + UserRole enum + role→permission mapping.
    permissions.dart         The master list of granular permissions.
    content_models.dart      Every content type: events, committees, gallery images,
                             fundraising campaigns/orders/vendors, legal docs, …
    donation.dart, audit.dart

  services/                  Talk to the outside world. Screens never call Firebase
                             directly — they go through these.
    firestore_service.dart   Reads/writes for every collection. In demo mode it swaps
                             in an in-memory store so the whole app works offline.
    auth_service.dart        All sign-in methods (+ demo simulation).
    geocoding_service.dart   Address → latitude/longitude via the free US Census API.
    paypal_service.dart      Donation checkout (real PayPal or simulated in demo).
    history_suggestions_service.dart  "On This Day" feed for history facts.

  providers/                 App-wide state (ChangeNotifier + provider package).
    auth_provider.dart       Who is signed in and their profile/role.
    theme_provider.dart      Light/dark/system theme choice.

  widgets/                   Reusable UI: responsive scaffold, cards, image widget,
                             nav destinations, history section.
  screens/                   One screen per public section (events, gallery, …).
  screens/admin/             The Admin Dashboard: one tab per content area, gated by
                             the current user's permissions, plus the editors.
  data/demo_data.dart        All demo/seed content, including the starter Terms of
                             Use & Privacy Policy templates.

functions/                   Cloud Functions (QR sign-in token minting, PayPal capture).
firestore.rules              Server-side security: who may read/write each collection.
storage.rules                Upload rules for images (size/type limits).
cors.json                    Storage bucket CORS policy (applied by CI) so the web app
                             can render images.
.github/workflows/deploy.yml CI: analyze + test + build on every PR; deploy on main.
```

State management: **provider**. Routing: **go_router**. Backend: **Firebase**.

### How data flows (worth understanding first)

1. A screen asks `FirestoreService` for a **stream** of models
   (e.g. `fs.events()` → `Stream<List<SchoolEvent>>`).
2. The service maps Firestore snapshots into model objects via `Model.fromDoc`.
3. The screen renders the stream with a `StreamBuilder` (or the shared
   `StreamListView` widget), so the UI updates live whenever the database changes.
4. Admin editors return an edited model object; the caller saves it with
   `fs.upsert(collection, item)`, which writes `item.toMap()` back to Firestore.
5. In **demo mode** the same service methods read/write an in-memory map instead,
   which is why the entire app works with no backend configured.

---

## 🚀 Getting started

### 1. Prerequisites
- [Flutter](https://docs.flutter.dev/get-started/install) stable — the project requires
  Dart SDK **3.5+** (any recent stable Flutter works; CI currently pins Flutter
  **3.44.x**).
- A [Firebase](https://console.firebase.google.com/) project (only needed to go live).
- The Firebase CLI: `npm i -g firebase-tools` (only needed for manual deploys).

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Run in demo mode (no backend needed)
```bash
flutter run -d chrome
```
The app boots with sample data. Sign in with any email — use an address containing
`admin` (e.g. `admin@school.org`) to unlock the **Admin Dashboard**.

### 4. Connect Firebase (go live)
```bash
dart pub global activate flutterfire_cli
flutterfire configure        # regenerates lib/firebase_options.dart with real values
```
In the Firebase console:
- **Authentication → Sign-in method**: enable Email/Password (turn on *Email link* for
  the one-time-code flow), plus Google/Facebook if you want them.
- Create a **Cloud Firestore** database and a **Storage** bucket.

Once `firebase_options.dart` has real values, `AppConfig.demoMode` becomes `false`
automatically and the app uses Firebase.

### 5. Deploy

**Preferred: let CI do it.** Merging to `main` automatically builds, tests, and deploys
Hosting, Firestore rules, Storage rules, and the Storage CORS policy (see below).

**Manual deploy** (if you ever need it):
```bash
flutter build web --release --no-tree-shake-icons --pwa-strategy=none
firebase deploy --only hosting,firestore:rules,storage
```
Build flags explained:
- `--no-tree-shake-icons` ships the full icon font so no glyph is ever missing.
- `--pwa-strategy=none` disables the offline service worker so users always get the
  newest deploy without hard-refreshing.

One-time bucket CORS (CI also applies this on every deploy — it's idempotent):
```bash
gcloud storage buckets update gs://<project-id>.firebasestorage.app --cors-file=cors.json
```
Without CORS, Flutter web cannot draw Storage images (they render as broken-image
icons), because the CanvasKit renderer fetches image bytes over HTTP.

---

## 🔐 Roles & permissions

Roles live on each user's `/users/{uid}` profile document. New sign-ups default to
**Supporter**. A **Web Admin** manages roles, delegated permissions, and committee
memberships in-app (Admin → Users & Roles); every change is written to an audit log.
Self-elevation is blocked by `firestore.rules`.

| Role | Gets |
| --- | --- |
| **Guest / Supporter / Member** | Browse public content; Members+ can submit funding requests and volunteer |
| **Contributor** | Manage Meetings & Minutes, History facts, and the Gallery |
| **Sponsor** | A profile organization field and sponsor-facing content |
| **Fundraising Volunteer** | Add fundraising orders; update payment/fulfillment status |
| **Fundraising Vendor / Sponsor** | Scoped read access to the fundraising module |
| **Fundraising Admin** | Full control of fundraising campaigns, products, vendors, orders |
| **Policy Admin** | Edit the Terms of Use & Privacy Policy |
| **Administrator** | Manage all content areas |
| **Web Admin** | Everything, plus Users & Roles and the audit log |

Beyond base roles, any single permission (see `lib/models/permissions.dart`) can be
**delegated** to any user with an optional expiry date — useful for temporary helpers.

## 🌱 Seeding content

A fresh Firestore database starts empty. Sign in as an **Administrator/Web Admin**, open
the **Admin Dashboard**, and click **Load sample content** to populate every collection
(events, volunteering, committees & leadership, sponsorships, fundraisers, fundraising
campaigns, meetings, FAQs, gallery, legal documents). It's idempotent — re-running
overwrites the same sample docs rather than duplicating them.

> Bootstrapping the first admin: new sign-ups default to *Supporter*. Promote your own
> account once by setting `role: "webAdmin"` on your `users/{uid}` doc in the Firebase
> console; after that you can manage roles in-app.

## ⚖️ Terms of Use & Privacy Policy

The app ships **starter templates** (in `lib/data/demo_data.dart`) that a **Policy
Admin** edits and publishes in-app (Admin → Legal). They are drafts with
`[PLACEHOLDERS]` — have a licensed attorney review them before relying on them.

> **Note:** once a document has been published, it lives in Firestore and is no longer
> read from the template. If the templates change in a new app version (for example to
> cover a new feature that collects data), the Policy Admin must review and re-publish
> the updated language in-app.

## 🔒 About secrets & PII (read before contributing)

- `lib/firebase_options.dart` contains the Firebase **web API key and app id**. These
  are **public identifiers, not secrets** — every Firebase web app ships them to the
  browser. Actual access control comes from `firestore.rules` / `storage.rules`.
- Real secrets never belong in this repo:
  - The CI deploy key is the `FIREBASE_SERVICE_ACCOUNT` **GitHub Actions secret**.
  - PayPal's secret & webhook id are **Cloud Functions secrets**
    (`firebase functions:secrets:set PAYPAL_SECRET` / `PAYPAL_WEBHOOK_ID`). Only the
    public client id may appear in app code (via `--dart-define=PAYPAL_CLIENT_ID=…`).
- **PII lives in three places** — treat them carefully:
  - `/users/*` — profiles (email, phone, address). Readable only by signed-in users;
    writable only by the owner (and role/grants/committees only by Web Admins).
  - `/fundraising_orders/*` — customer names, contacts, delivery addresses. Readable
    **only** by fundraising staff; never rendered on public pages.
  - `/donations/*` — donor gives name/amount; readable only by the donor and donation
    managers.
- Demo/seed data uses fictional 555 phone numbers. The seeded leadership names and
  committee contact emails mirror the club's **already-public** website content.

## 🔑 One-time email-link sign-in

Passwordless "one-time code" login uses Firebase's email-link flow. Enable **Email link
(passwordless sign-in)** under *Authentication → Sign-in method → Email/Password* in the
console. The app sends a link, remembers the email on the device, and completes sign-in
when the user returns (via `/finishSignIn`); if opened on another device it asks the user
to confirm their email.

## 🔑 QR-code sign-in (Cloud Function)

Cross-device flow: the web app creates a `qr_sessions/{id}` doc and shows a QR encoding a
`/pair?s=<id>` link. A phone that is already signed in opens it and approves, which calls
the **`approveQrSignIn`** Cloud Function (`functions/index.js`). The function mints a
Firebase custom token for the phone's user and writes it onto the session; the web app
exchanges it via `signInWithCustomToken`. In demo mode a "Simulate scan" button completes
the flow instantly.

Deploy the function (requires the **Blaze** plan):

```bash
cd functions && npm install && cd ..
firebase deploy --only functions,firestore:rules
```

## 🧪 Verify

```bash
flutter analyze
flutter test
flutter build web --release --no-tree-shake-icons --pwa-strategy=none
```

## ⚙️ Continuous deployment (no local commands)

`.github/workflows/deploy.yml` runs **analyze + test + build** on every pull request,
and on every push to `main` additionally deploys:

1. the web build to **Firebase Hosting**,
2. the **Storage CORS** policy (`cors.json`),
3. **Firestore rules**, and
4. **Storage rules**.

Once set up, you never run `flutter build` / `firebase deploy` by hand — merging a
change ships it.

**One-time setup — add a single repo secret:**
1. Firebase console → **Project settings → Service accounts → Generate new private key**
   (downloads a JSON key).
2. GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**,
   name it **`FIREBASE_SERVICE_ACCOUNT`**, and paste the entire JSON as the value.

The project id (`boosterclub-bda`) is set in the workflow and `.firebaserc`. To also
deploy Cloud Functions (QR sign-in, PayPal), add `,functions` to the deploy step once
the project is on the Blaze plan.

## 📝 Versioning

The app version is kept in step in three places — bump all of them together:
`pubspec.yaml` (`version:`), `lib/config/app_config.dart` (`appVersion`, shown in the
nav footer and on the loading splash), and `CHANGELOG.md`.
