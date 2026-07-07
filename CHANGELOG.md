# Changelog

Version shown in-app (nav footer) as `AppConfig.appVersion`, kept in step with
`pubspec.yaml`. Bumped on each iteration.

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
