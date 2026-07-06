# Changelog

Version shown in-app (nav footer) as `AppConfig.appVersion`, kept in step with
`pubspec.yaml`. Bumped on each iteration.

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
