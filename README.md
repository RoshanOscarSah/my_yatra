# MyYatra

**Every district. A new story.** A Flutter app that helps travellers in Nepal record where
they have been, understand their travel personality (Journey DNA), find the gaps in their
travels and get explainable suggestions for the next district to visit.

Built to the requirements in [`docs/`](docs/): the sprint guide, the project workbook
(56 user stories, US-1.1 to US-15.7, and test cases TC-01 to TC-40) and the proposal.

> Map rendering and district data adapted from [Hariyo Naksha](https://github.com/RoshanOscarSah/hariyo_naksha) by Roshan Sah.

## Features by sprint

| Sprint | What is in the app |
|---|---|
| 1 Accounts & privacy | Email/password and Google sign-in, password rules, generic login errors, password reset, privacy policy acceptance, 15-minute idle sign-out, "Your data is private" and data-used-by-AI screen, edit profile, delete account with all data |
| 2 Onboarding | Interests, travel habits, planning preferences, past districts (all skippable); edit later in Preferences |
| 3 Map & districts | Interactive SVG map of 77 districts (visited / recommended / other), explore list with province and type filters, district page (types, seasons, cost, transport, festivals, food, places) |
| 4 Visits | Mark visited with date or "before MyYatra", record places and activities, unmark, bulk add |
| 5 Journey DNA | Weighted DNA score per experience type, radar chart, explanation, Mixed Traveller, gap analysis, province coverage |
| 6 Recommendations | Ranked, explained suggestions (DNA + gaps + fit + less-explored), budget/distance/season filters, weekly picks, helpful / not interested / report with undo |
| 7 Journal | Entries with dates, activities, story and up to 6 photos (offline queue), digital postcard |
| 8 History & stats | Timeline with district/year filters, journey detail, statistics per year and province |
| 9 Itineraries | Day-by-day plans with budget vs estimated cost, share, save offline |
| 10–12 Gamification, offline, safety | Badges and gap challenges (can be switched off), offline downloads with sizes, emergency numbers, "I'm safe" SMS check-in, safety alerts with expiry |
| 13–14 Community & feedback | One review per visited district, app feedback, wrong-info and recommendation reports with status |
| 15 Admin | Seed data, edit districts and places, alerts, feedback inbox, review moderation, content analytics (aggregates only), change log with date filter |

## Project layout

```
lib/
  app/            theme, env (emulator, limits), app shell, auth gate, idle timeout
  core/
    data/         bundled seed for all 77 districts
    models/       Firestore models
    repositories/ auth, user, district, community (Firestore / Storage)
    providers/    auth, profile, districts, visits, journal, itineraries, offline, connectivity
    widgets/      Nepal map, district picker, common UI
  features/
    dna/engine/              DnaCalculator (pure Dart, unit tested)
    recommendations/engine/  Recommender (pure Dart, unit tested)
    gamification/engine/     stats, badges, challenges (pure Dart, unit tested)
    ...           one folder per feature (auth, onboarding, districts, journal, admin, ...)
firestore.rules   owner-only user data, admin-only content writes
storage.rules     owner-only photos, 10 MB, image types only
```

## Run locally (Firebase emulators, no real project needed)

The app ships with a placeholder `demo-myyatra` config and connects to the local
emulators automatically.

Requirements: Flutter 3.41+, Node 18+, Java 21+ (needed by the emulators), and the Firebase CLI (`npm i -g firebase-tools`).

```bash
firebase emulators:start
```

In a second terminal:

```bash
flutter pub get
flutter run -d chrome
```

Emulator UI: http://localhost:4000 (Auth 9099, Firestore 8081, Storage 9199). On an Android emulator the app uses `10.0.2.2` to reach them.

### Make an admin

1. Register in the app.
2. Open the Emulator UI → Firestore → `users/{your uid}` and set `role` to `admin`.
3. Reopen Profile → **Admin** → **Seed 77 districts**. Until seeded, the app reads the bundled data.

Users cannot change their own role: the security rules block it.

## Use a real Firebase project

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This overwrites `lib/firebase_options.dart`. Then enable Email/Password and Google in
Authentication, create Firestore and Storage, and deploy the rules:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Never commit keystores (`*.jks`), `key.properties`, service-account JSON or API secrets;
they are in `.gitignore`.

## Tests

```bash
flutter test
```

Unit tests cover the DNA calculator (persona checks), the recommender (TC-19, 20, 21, 23, 24),
stats and badges (TC-27, 28) and the 77-district seed (province counts).

## Design decisions

- **Explainable, rule-based AI.** DNA score per type = 100 × (0.4 interest + 0.4 visits + 0.2 activities).
  Recommendation score = 0.45 DNA + 0.25 gap + 0.20 fit (budget, season, distance) + 0.10 less-explored,
  and every suggestion shows its reasons. No personal data leaves Firebase.
- **Privacy by default.** All user data lives under `users/{uid}`, readable only by its owner.
  Admin analytics use aggregate visit counts only.
- **Works offline.** Firestore persistence, a 4-second soft timeout on writes, saved district pages
  and itineraries in local storage, and a photo upload queue that sends on reconnect.
- **Map from Hariyo Naksha.** The SVG and district outlines are reused; district names in the
  seed keep the SVG's own spellings so every polygon matches.

## Before release

- Verify the emergency numbers on the safety screen (100 police, 102 ambulance, 101 fire, 1144 tourist police) with current official sources.
- Review the seed descriptions, costs and festivals with a local expert.
