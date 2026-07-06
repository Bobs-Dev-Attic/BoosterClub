# 🦁 Booster Club

A responsive **Flutter** web & mobile app for a High School Booster Club, designed to be
hosted on **Firebase Hosting** with **Firebase Auth** and **Cloud Firestore**.

Members, supporters, sponsors and administrators can browse and manage content including
school events, volunteering opportunities, corporate sponsorships, donations, funding
requests, fundraising events, Booster Club meetings & minutes, and an FAQ.

The UI is fully responsive — a navigation rail on desktop/laptop browsers and a
drawer + bottom navigation on phones.

---

## ✨ Features

| Area | What you get |
| --- | --- |
| **Content** | Events, Volunteering, Sponsorships, Donations, Funding Requests, Fundraisers, Meetings & Minutes, FAQ |
| **Auth** | Email/Password, Email one-time link (passwordless), QR-code sign-in, Google, Facebook, plus password reset |
| **Roles** | Guest → Supporter → Member → Sponsor → Administrator → Web Admin |
| **Content management** | Administrators & Web Admins get an in-app Admin Dashboard to create/edit/delete every content type |
| **Accounts** | Members manage their own profile; members+ can submit funding requests |
| **Responsive** | Looks good on any phone and on a desktop/laptop browser |
| **Demo mode** | Runs with seeded sample data until Firebase is configured, so you can preview instantly |

## 🏗️ Architecture

```
lib/
  main.dart                 App entry, Firebase init (falls back to demo mode)
  firebase_options.dart     Firebase config (placeholder — run `flutterfire configure`)
  config/app_config.dart    App name, school name, demo-mode flag
  theme/app_theme.dart      Material 3 theme (navy + gold)
  router/app_router.dart    go_router routes inside a responsive shell
  models/                   AppUser (+roles) and content models
  data/demo_data.dart       Seed data for demo mode
  services/
    auth_service.dart       All sign-in methods (+ demo simulation)
    firestore_service.dart  Reads/writes for every collection (+ in-memory demo store)
  providers/auth_provider.dart   Auth state (ChangeNotifier)
  widgets/                  Responsive scaffold, shared UI, nav destinations
  screens/                  One screen per section + login/qr/profile
  screens/admin/            Admin dashboard + content edit forms
```

State management: **provider**. Routing: **go_router**. Backend: **Firebase**.

---

## 🚀 Getting started

### 1. Prerequisites
- [Flutter](https://docs.flutter.dev/get-started/install) 3.24+ (Dart 3.5+)
- A [Firebase](https://console.firebase.google.com/) project
- The Firebase CLI: `npm i -g firebase-tools`

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
In the Firebase console, enable the sign-in providers you want under
**Authentication → Sign-in method**: Email/Password (turn on *Email link* for the
one-time-code flow), Google, and Facebook. Create a **Cloud Firestore** database.

Once `firebase_options.dart` has real credentials, `AppConfig.demoMode` becomes `false`
automatically and the app uses Firebase.

### 5. Deploy to Firebase Hosting
```bash
# Set your project id in .firebaserc first
flutter build web --release
firebase deploy --only hosting,firestore:rules
```

---

## 🔐 Roles & permissions

Roles live on each user's `/users/{uid}` profile document. New sign-ups default to
**Supporter**. A **Web Admin** promotes users to higher roles (in production, do this from
the Firebase console or a custom admin tool — self-elevation is blocked by the security
rules in `firestore.rules`).

- **Administrator / Web Admin** — manage all content via the Admin Dashboard.
- **Web Admin** — additionally manages users and roles.
- **Member+** — can submit funding requests.
- **Everyone (incl. guests)** — can browse all public content.

## 🌱 Seeding content

A fresh Firestore database starts empty. Sign in as an **Administrator/Web Admin**, open the
**Admin Dashboard**, and click **Load sample content** to populate every collection with a
starter set (events, volunteer shifts, sponsorship tiers, fundraisers, meetings, FAQs). It's
idempotent — re-running overwrites the same sample docs rather than duplicating them. Edit or
delete anything from there.

> Bootstrapping the first admin: new sign-ups default to *Supporter*. Promote your own
> account once by setting `role: "webAdmin"` on your `users/{uid}` doc in the Firebase
> console; after that you can manage roles in-app.

## 🔑 One-time email-link sign-in

Passwordless "one-time code" login uses Firebase's email-link flow. Enable **Email link
(passwordless sign-in)** under *Authentication → Sign-in method → Email/Password* in the
console. The app sends a link, remembers the email on the device, and completes sign-in when
the user returns (via `/finishSignIn`); if opened on another device it asks the user to
confirm their email.

## 🔑 QR-code sign-in (Cloud Function)

Cross-device flow: the web app creates a `qr_sessions/{id}` doc and shows a QR encoding a
`/pair?s=<id>` link. A phone that is already signed in opens it and approves, which calls the
**`approveQrSignIn`** Cloud Function (`functions/index.js`). The function mints a Firebase
custom token for the phone's user and writes it onto the session; the web app exchanges it via
`signInWithCustomToken`. In demo mode a "Simulate scan" button completes the flow instantly.

Deploy the function (requires the **Blaze** plan):

```bash
cd functions && npm install && cd ..
firebase deploy --only functions,firestore:rules
```

## 🧪 Verify

```bash
flutter analyze
flutter test
flutter build web --release
```

## ⚙️ Continuous deployment (no local commands)

`.github/workflows/deploy.yml` builds, tests, and **auto-deploys** to Firebase (Hosting +
Firestore rules) on every push to `main`. Once set up, you never run `flutter build` /
`firebase deploy` by hand — merging a change ships it.

**One-time setup — add a single repo secret:**
1. Firebase console → **Project settings → Service accounts → Generate new private key**
   (downloads a JSON key).
2. GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**,
   name it **`FIREBASE_SERVICE_ACCOUNT`**, and paste the entire JSON as the value.

That's it. The project id (`boosterclub-bda`) is already set in the workflow. To also deploy
Cloud Functions (QR sign-in), add `,functions` to the deploy step once the project is on the
Blaze plan.
