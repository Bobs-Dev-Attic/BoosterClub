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

## 🔑 QR-code sign-in

The web/desktop app shows a QR code encoding a short-lived pairing token. A phone that is
already signed in scans it to approve the session; a Cloud Function then mints a Firebase
custom token that the web app exchanges (`signInWithCustomToken`). In demo mode a
"Simulate scan" button completes the flow instantly. Wiring the Cloud Function is the only
backend piece required to make this production-ready.

## 🧪 Verify

```bash
flutter analyze
flutter test
flutter build web --release
```

## ⚙️ Continuous deployment

`.github/workflows/deploy.yml` builds the web app and deploys to Firebase Hosting on push
to the default branch. Add a `FIREBASE_SERVICE_ACCOUNT` repo secret (a Firebase service
account JSON) and set your project id to enable it.
