# MyYatra — Sprint-by-Sprint Build Guide

A build guide for team **YatraCrew** (Pooja, Pratish, Chhanda, Lok Bahadur). It turns the proposal and the planning workbook into concrete work, sprint by sprint, starting from the **Hariyo Naksha** Flutter app (`github.com/RoshanOscarSah/hariyo_naksha`).

This guide gives you **tasks, file plans, hints and "done when" checks**, not finished code. Each person writes their own stories, so the Git history and the sprint sheets show real progress. If you get stuck, bring the specific code and error to Roshan.

> **Honesty checklist (do this once, before Sprint 1 code)**
> - Ask the instructor whether starting from an existing open repo is allowed when it is credited.
> - If it is: say so in `README.md` ("Map rendering and district data adapted from Hariyo Naksha by Roshan Sah") and in the report's System Design section.
> - Commit your own work, as you do it, from your own GitHub account.

---

## 0. Where you are right now

| Item | Status |
|---|---|
| Today | 19 Nov 2026 → **Sprint 3** (16–20 Nov) by the workbook dates |
| Built so far | Nothing (all 56 stories "Not started") |
| Total | 56 stories · 107 story points · 9 sprints · ends 1 Jan 2027 |

**Catch-up plan:** run the Sprint 1 and Sprint 2 stories together over 20–29 Nov ("Sprint 1–2 catch-up"), then shift the later sprints by one week. Update the dates in *Agile Release Plan* and record why in the Sprint 1 retrospective. Teachers prefer an honest re-plan to a fake "on track".

---

## 1. Decisions to make before writing code

These are the open items in the workbook's *References & Assumptions* (C-04 to C-07, X-01). Below each is a recommended answer. Agree on them as a team and write them into the workbook.

| ID | Question | Recommended answer | Why |
|---|---|---|---|
| C-04 | Which Firebase services? | **Auth** (email/password + Google), **Cloud Firestore** (all data), **Cloud Storage** (journal photos) | Matches the architecture figure. ⚠ Check the current Firebase pricing page: Cloud Storage may need the Blaze (pay-as-you-go) plan. If it does and you can't add a card, store compressed photos locally plus a small thumbnail in Firestore, and note the deviation. |
| C-05 | How does Python connect? | **Phase 1:** rule-based engine in Dart (`lib/features/recommendations/engine/`). **Phase 2 (optional, Sprint 5+):** move the same formula to a Python Cloud Function or a small FastAPI service that the app calls over HTTPS. | The proposal itself says rule-based/content-based first. Keeping the engine behind a Dart interface means swapping to Python later changes only one file. |
| C-06 | Admin area: web or in-app? | **In-app**, behind a role check (an `admin` flag on the user document, enforced in Firestore rules) | One codebase, and TC-38 can still be tested properly because the rules block non-admins on the server. |
| C-07 / X-02 | DNA categories: 6 or 8? | **6:** Nature, Culture, Adventure, Food, History, Spiritual | Matches the stories (US-2.1) **and** the Figma "Travel interests" screen. Map the survey's 8 types onto these 6 in the report. |
| X-01 | Scrum Master clash (S4 twice, S7 nobody) | e.g. Pooja S1, S7, S9 · Lok S2, S5 · Chhanda S3, S6 · Pratish S4, S8 | The proposal already shows this version, so make the workbook match it. |
| — | State management | **Provider** (already in Hariyo Naksha) | See §3. Remove `flutter_riverpod` and `freezed` from `pubspec.yaml`: Hariyo lists them but doesn't use them. |

---

## 2. Starting from Hariyo Naksha: keep, adapt, drop

Fork or copy the repo into a **new** repo called `my_yatra`. Make the first commit "Initial import of Hariyo Naksha base (credited)", so the starting point is visible in the history.

### Keep (and credit)
| Hariyo file | Use in MyYatra |
|---|---|
| `assets/maps/nepal_map_with_data.svg` | The 77-district map. Groups `p1`–`p7` are the provinces (14 + 8 + 13 + 11 + 12 + 10 + 9 = 77). |
| `lib/utils/svg_loader.dart` | Parse the districts **and** read the parent `<g>` label to get the province (see Sprint 1 hint). |
| `lib/widgets/district_clipper.dart` (`DistrictPainter`) | Map drawing. Add a third colour for "recommended" (US-3.3). |
| `map_screen.dart` (the `InteractiveViewer` + `GestureDetector` + `ClipPath` part, roughly lines 630–700) | The map widget: pan, zoom and tap a district. Extract it into `widgets/nepal_map.dart`. |
| `lib/utils/achievements.dart` | Starting point for badges (US-9.1). |
| `lib/utils/share_helper.dart` | Starting point for sharing postcards (US-7.4). |
| `widgets/district_note_sheet.dart` | Pattern for the "record places & activities" bottom sheet (US-3.4). |
| `widgets/alphabet_scroll_bar.dart` | The A–Z scroller on the 77-district list (US-3.1). |

### Adapt
| Hariyo | Change to |
|---|---|
| `models/district.dart` (id, name, svgPath, isVisited) | Split into **`District`** (static: id, name, province, svgPath, plus the Firestore fields from §4) and **`Visit`** (per user: districtId, date, places, activities). `isVisited` should no longer live on the district. |
| `StorageManager` (SharedPreferences) | Firestore repositories. Keep SharedPreferences only for small settings (e.g. "seen onboarding"). |
| `onboarding_screen.dart` | Rebuild as the Figma flow: Welcome → Sign in/Create account → Interests (01/03) → Habits (02/03) → Planning + visited districts (03/03). |
| Theme (green, dark) | MyYatra theme from the Figma (see §5). |
| `main_screen.dart` bottom nav | Five tabs as in Figma: **Home · Explore · For you · Journal · Profile**. |

### Drop
Checklist, tips, backup/restore, reset screens, reminder service and the alphabet-only progress page. They are not in the 56 stories. Removing them is a good small commit for Sprint 1.

### Data clean-up
Some SVG labels need fixing before they become district names: `Lamjing` → `Lamjung`, the lowercase names in `p7` (`kailali`, `doti`…) → Title Case, `Rukum west` → `Rukum West`. Put the clean names in a seed file, not in the SVG.

---

## 3. Provider in 10 minutes (read before Sprint 1)

You already know widgets. Provider answers one question: **"How do many widgets share the same data and rebuild when it changes?"**

**1. Hold the data in a class that extends `ChangeNotifier`, and call `notifyListeners()` after every change.** Hariyo's `DistrictProvider` is a good real example:

```dart
class DistrictProvider extends ChangeNotifier {
  List<District> _districts = [];
  List<District> get districts => _districts;      // read-only from outside

  Future<void> toggleDistrictVisited(String id) async {
    // ...change the data...
    notifyListeners();                              // "I changed. Rebuild whoever listens."
  }
}
```

**2. Put it above the widgets that need it.** Hariyo does this in `main.dart` with `MultiProvider`:

```dart
MultiProvider(
  providers: [ChangeNotifierProvider(create: (_) => DistrictProvider())],
  child: MaterialApp(...),
)
```

**3. Use it inside widgets. There are three ways:**

| Code | When | Rebuilds? |
|---|---|---|
| `context.watch<DistrictProvider>().districts` | Inside `build()`, when the UI shows the data | Yes, on every `notifyListeners()` |
| `context.read<DistrictProvider>().toggleDistrictVisited(id)` | Inside `onPressed` / `onTap` (actions) | No |
| `Consumer<DistrictProvider>(builder: (ctx, p, _) => ...)` | When only a small part of a big widget should rebuild | Only the builder part |

**Rules of thumb**
- Use `watch` in `build`, `read` in callbacks. Using `watch` in a callback throws an error.
- Keep Firestore calls in a *repository* class. The provider calls the repository; the widget calls the provider. Widget → Provider → Repository → Firebase.
- For a provider that depends on another one (e.g. `DnaProvider` needs `VisitProvider` and `ProfileProvider`), look up `ChangeNotifierProxyProvider`. That's how US-4.3 "auto-refresh" works.

**Practice task (30 min, everyone, before Sprint 1):** add a `CounterProvider` to a blank Flutter app with + and − buttons and a `Text` that shows the count on another screen. If that works, you understand everything the guide needs.

---

## 4. Target architecture

### Folder layout (feature-first)

```
lib/
  main.dart                     # Firebase.initializeApp, MultiProvider, routes
  app/theme.dart                # colours + text styles from Figma
  app/router.dart               # named routes + auth gate
  core/models/                  # District, Place, Visit, JournalEntry, Review, Alert, Feedback, DnaSnapshot, UserProfile
  core/repositories/            # one per Firestore collection
  core/widgets/nepal_map.dart   # extracted from Hariyo map_screen
  features/
    auth/          (S1)  welcome, sign_in, register, forgot_password, idle_timeout
    onboarding/    (S2)  interests, habits, planning, visited_districts
    profile/       (S2)  profile, edit_profile, privacy_data_use, settings
    districts/     (S3)  explore (list + map), district_page, record_visit_sheet
    dna/           (S4)  dna_page, radar_chart, gap_analysis
    recommendations/(S5) engine/, for_you_page, filters, weekly_picks
    journal/       (S6)  journal_list, entry_form, history_timeline, stats, postcard
    gamification/  (S7)  badges, challenges
    itinerary/     (S7)
    offline/       (S8)
    safety/        (S8)
    reviews/       (S8)
    feedback/      (S9)
    admin/         (S1, S8, S9) districts, places, alerts, inbox, analytics, changes, moderation
```

### Firestore model (extends the ER diagram in proposal Figure 9)

| Collection | Key fields | Who can read / write |
|---|---|---|
| `users/{uid}` | name, email, role (`traveller`/`admin`), policyAcceptedAt, interests[], habits{}, planning{budget, distance, season, startDistrictId}, gamificationOn, emergencyContact{} | owner only (admin cannot read personal data) |
| `users/{uid}/visits/{id}` | districtId, date, places[], activities[] | owner |
| `users/{uid}/journal/{id}` | districtId, startDate, endDate, activities[], story, photoUrls[], draft | owner |
| `users/{uid}/dna/current` | type, scores{6 categories}, gaps{}, explanation, updatedAt | owner |
| `users/{uid}/recFeedback/{districtId}` | value (`helpful`/`not_interested`), at | owner |
| `districts/{id}` (77) | name, province, description, experienceTypes[], bestSeasons[], costLevel, transport, safetyNotes, festivals[], foods[], lessExplored (bool) | read: signed-in · write: admin |
| `districts/{id}/places/{id}` | name, experienceType, description | read: signed-in · write: admin |
| `reviews/{id}` | districtId, uid, displayName, rating, text, createdAt | read: signed-in · create: owner of a visit · delete: author or admin |
| `alerts/{id}` | districtId, message, expiresAt, createdBy | read: signed-in · write: admin |
| `feedback/{id}` | type (`app`/`recommendation`/`district_info`), uid, rating, category, text, status (`new`/`reviewed`/`resolved`) | create: signed-in · read/update: admin |
| `changeLog/{id}` | entity, entityId, field, oldValue, newValue, adminUid, at | read/write: admin |
| `stats/districtVisits` | {districtId: count} (totals only, NFR-14) | read: admin · write: Cloud Function or counter increment |

**Rules hint (the core of TC-05 and TC-38):** write `firestore.rules` in Sprint 1 and test it with the Firebase Emulator. The key idea:

```
function isAdmin() {
  return request.auth != null &&
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
match /users/{uid}/{document=**} { allow read, write: if request.auth.uid == uid; }
match /districts/{id}           { allow read: if request.auth != null; allow write: if isAdmin(); }
```

Users must not be able to set their own `role`. Add a rule that blocks changing that field, and set admins by hand in the console.

---

## 5. Design system (from the Figma screens in the proposal)

Take the exact values from the Figma file. These are close approximations from the screenshots:

| Token | Approx. | Used for |
|---|---|---|
| `background` | `#FFF6EC` (warm cream) | all screens |
| `primary` | `#8B2635` (maroon) | buttons, selected chips, active tab, checkmarks |
| `primarySoft` | `#F3DDE0` | selected interest card, province chips, tags |
| `lavender` | `#EDE6F6` | DNA personality card, profile header |
| `goldSoft` | `#FBF0D9` | "Follow your curiosity" tip card |
| `textPrimary` | `#2A1E1E` | headings |
| `textSecondary` | `#6E625F` | body text |

- **Headings:** a serif such as *Lora*, *Fraunces* or *Playfair Display* ("Every district. A new story."). **Body:** a clean sans such as *DM Sans* or *Inter* (Inter is already in Hariyo's assets).
- **Shapes:** large rounded cards (radius ~16), full-width pill buttons (~56 px tall) with a trailing arrow, light 1 px borders.
- **Screens to match:** 01 Welcome · 02 Sign in (tab switch Sign in / Create account, eye icon, Google/Apple) · 03 Travel interests (2 × 3 grid, step 01/03, Skip) · 05 Explore (search + filter, province chips, footprint map with %, district card) · 07 Journey DNA (personality card, 6-axis radar, tip card, CTA) · 11 Profile (stats row: districts / % / badges, menu list, Log out).

**Sprint 1 task for whoever is free:** build `app/theme.dart` plus three shared widgets (`PrimaryButton`, `SelectableCard`, `TagChip`) so every screen looks consistent from the start.

---

## 6. Sprint plan

Each story lists: **owner** (from *Agile Release Plan*) · **points** · what to build · **reuse** · **hints** · **done when** (test case IDs from the *Test Cases* sheet).

Every sprint ends the same way: demo → fill **Actual result / Status / Tester / Date** in *Test Cases* → move the story to Done on the sprint sheet → write the review and retrospective.

---

### Sprint 1 — Secure sign-in foundation and admin district/place data (11 pts)

**Setup (everyone, day 1):** create the Firebase project, run `flutterfire configure`, add `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`. Commit `firebase_options.dart` **but not** service-account keys. Also remove Hariyo's `upload-keystore.jks` from the new repo, because signing keys never belong in Git.

| Story | Owner | Pts | Build | Hints | Done when |
|---|---|---|---|---|---|
| **US-1.1** Register & accept policy | Chhanda | 2 | Create-account tab on screen 02: name, email, password, a policy checkbox with a link to the privacy page. On success, create `users/{uid}` with `policyAcceptedAt`. | `createUserWithEmailAndPassword`, then write the user doc. Disable the button until the box is ticked, and highlight the link if they try anyway. | TC-01, TC-02 |
| **US-1.2** Login & show password | Pratish | 1.5 | Sign-in tab, eye-icon toggle, "stay signed in". | `obscureText` bound to a bool. Firebase keeps the session by default on mobile. Listen to `authStateChanges()` in an `AuthGate` widget to choose between Welcome and Home. | Manual: eye toggles; app reopens signed in |
| **US-1.3** Reset password | Pratish | 2 | "Forgot password?" flow. | Firebase sends a **single-use, expiring reset link** (`sendPasswordResetEmail`), not a typed code. That meets the intent of the acceptance criteria (single use, expires). Record it as a design decision in the workbook rather than building your own OTP system. | TC-03 |
| **US-1.4** Sign out & idle timeout | Lok | 1 | Sign-out on Profile. Idle sign-out after N minutes (agree on N and record it as NFR). | Wrap the app in a `Listener(onPointerDown: ...)` that resets a `Timer`. When the timer fires: `signOut()` and `pushNamedAndRemoveUntil('/welcome', (_) => false)` so Back can't reopen protected pages. | TC-04 |
| **US-15.1** Manage district data | Pooja | 2.5 | (a) **Seed script:** write the 77 districts with province (from the SVG groups) into `districts`. (b) Admin screen: list → edit form for all §4 district fields. | Seed once with a hidden admin-only "Seed districts" button, or a small Dart script using the emulator. In `svg_loader`, read the province from the parent `<g>`'s `inkscape:label` (`p1`…`p7`) and map it to Koshi, Madhesh, Bagmati, Gandaki, Lumbini, Karnali, Sudurpashchim. Every save also writes a `changeLog` doc (needed for US-15.4 later). | TC-38, TC-39 |
| **US-15.2** Manage places | Pooja | 2 | Admin: add/edit places inside a district (name, experience type from the 6, description). | Subcollection `districts/{id}/places`. Validate that all fields are filled. | Manual + changeLog entry appears |

**Also in Sprint 1:** `firestore.rules` (§4), `app/theme.dart`, and removing the unused Hariyo screens.

---

### Sprint 2 — Privacy, profile and onboarding preferences (8.5 pts)

| Story | Owner | Pts | Build | Hints | Done when |
|---|---|---|---|---|---|
| **US-1.5** Privacy & data use | Lok | 1.5 | Profile → Privacy & security: "Your data is private" + a **Data used by AI** list (interests, habits, planning, visits, feedback). | It is mostly static text, but the private-by-default part is proven by the **rules**. Test it with two accounts. | TC-05, TC-06 |
| **US-1.6** Edit profile / delete account | Chhanda | 2 | Edit name etc.; Delete account with password re-entry. | Delete order: subcollections → user doc → photos in Storage → `user.delete()`. Firebase needs a recent login, so use `reauthenticateWithCredential`. Client-side deletion of subcollections is fine at this size. | TC-07 |
| **US-2.1** Choose interests | Chhanda | 1 | Screen 03 (6-card grid, step 01/03). | A reusable `SelectableCard`. The Continue button needs at least one selection. Save to `users/{uid}.interests`. | TC-08 |
| **US-2.2** Travel habits | Lok | 1 | Step 02/03: frequency, style, companions. | Chips/radio groups → `habits{}`. | Manual |
| **US-2.3** Budget, distance & season | Pratish | 1.5 | Step 03/03 part 1: budget range, distance preference, season, starting district. | Starting district: a searchable dropdown from `districts`. These become the default recommendation filters in S5. | TC-09 (finished in S5) |
| **US-2.4** Mark visited districts | Pooja | 1.5 | Step 03/03 part 2: tick districts already visited (list grouped by province + search). | Reuse `alphabet_scroll_bar`. Write a `visits` doc per tick, with the date left empty or "before MyYatra". | Manual |

Create a `ProfileProvider` that loads `users/{uid}` once and exposes the interests, habits and planning. Many later features read from it.

---

### Sprint 3 — District browsing, visit tracking and district pages (12 pts)

| Story | Owner | Pts | Build | Hints | Done when |
|---|---|---|---|---|---|
| **US-2.5** Edit preferences | Chhanda | 1.5 | Profile → Settings → Preferences: reuse the S2 onboarding widgets, prefilled. | Build the onboarding steps as widgets that take an initial value and an `onChanged`, so they work in both places. | Manual |
| **US-3.1** Browse 77 districts | Pratish | 1.5 | Explore tab (screen 05): search, province chips, list with visited badges. | `DistrictProvider` loads `districts` once; `VisitProvider` streams `users/{uid}/visits`. Combine the two in the UI. | TC-10 |
| **US-3.2** Mark visited with date | Lok | 1.5 | "Mark visited" on the list, the map and the district page → date picker. | `VisitProvider.addVisit(districtId, date)`. Progress = distinct districtIds / 77. | TC-11 |
| **US-3.3** District map | Pooja | 3 | Footprint map on Explore + a full-screen map; visited / recommended / other in 3 colours; % badge. | Lift Hariyo's `InteractiveViewer` + `DistrictPainter` code into `core/widgets/nepal_map.dart`, passing it `Set<String> visitedIds` and `Set<String> recommendedIds`. Recommended stays empty until S5, which is fine. | TC-12 |
| **US-3.4** Record places & activities | Pratish | 2.5 | Bottom sheet on a visit: choose places from the district's `places`, or type your own; choose activity types. | Copy the layout pattern from Hariyo's `district_note_sheet.dart`. | TC-13 |
| **US-6.6** District page | Pooja | 2 | Description, experience-type tags, best season, cost, how to get there, Mark visited. | One `DistrictPage(districtId)` route. Leave labelled placeholder sections for festivals/food (S6), safety (S8), reviews (S8) and offline (S8). | Manual |

---

### Sprint 4 — Journey DNA and first gap views (12.5 pts)

**Agree on the formula first (½ day, whole team).** Write it into the report's §8.4. A simple, explainable version:

```
For each category c in {Nature, Culture, Adventure, Food, History, Spiritual}:
  interest(c) = 1 if chosen in onboarding else 0
  visits(c)   = share of the user's visited districts whose experienceTypes include c
  activity(c) = share of recorded activities tagged c
  score(c)    = 100 × (0.4·interest + 0.4·visits + 0.2·activity)

Type = "<top category> Explorer"; if the top two are within 10 points → "Mixed Traveller"
```

Put this in a **pure Dart class** with no Flutter or Firebase imports (`features/dna/engine/dna_calculator.dart`), so you can unit-test it with the five personas. Those tests count as evidence for the "AI" part of the module.

| Story | Owner | Pts | Build | Hints | Done when |
|---|---|---|---|---|---|
| **US-4.1** Generate Journey DNA | Pooja | 3 | `DnaCalculator` + personality card (screen 07). | Write `test/dna_calculator_test.dart`: Swati (nature-heavy) must come out as Nature Explorer, and so on. | TC-14 |
| **US-4.2** DNA chart | Chhanda | 1.5 | 6-axis radar chart. | Use `fl_chart`'s `RadarChart`, or draw it yourself with `CustomPainter` (you already have a painter from Hariyo to copy from). | Manual |
| **US-4.3** Auto-refresh | Lok | 2.5 | DNA and gaps recompute when visits or preferences change. | `ChangeNotifierProxyProvider2<VisitProvider, ProfileProvider, DnaProvider>`: its `update` runs whenever either input notifies. Save the result to `users/{uid}/dna/current`. | TC-15 |
| **US-4.4** DNA explanation | Pratish | 2 | 2–3 plain sentences explaining the type. | **Template text**, e.g. "You chose {interests} and {x}% of your trips were {top}…". This is honest and meets "explain in plain words". An LLM call is optional extra; if you add one, keep the key off the device (use a Cloud Function). | TC-16 |
| **US-5.1** Unexplored experience types | Chhanda | 2 | "Tried vs not tried" view of the 6 categories. | It's already in the DNA data (`visits(c) == 0`). | TC-17 |
| **US-5.2** Least-explored provinces | Lok | 1.5 | 7 provinces sorted by % visited. | District count per province: 14, 8, 13, 11, 12, 10, 9. | TC-18 |

---

### Sprint 5 — Ranked, explained, filterable recommendations (12 pts)

**Engine (in `features/recommendations/engine/recommender.dart`, pure Dart, unit-tested):**

```
for each district d NOT visited and NOT marked not_interested:
  dnaMatch   = avg score of user DNA over d.experienceTypes       (0..1)
  gapFill    = 1 if d covers a category the user hasn't tried     (0/1)
  fit        = matches budget, season, distance filters           (0..1)
  lessBonus  = d.lessExplored ? 1 : 0
  score = 0.45·dnaMatch + 0.25·gapFill + 0.20·fit + 0.10·lessBonus
reason = sentence built from the 1–2 biggest terms
```

This is exactly what proposal §8.4 describes, so the code and the report agree.

| Story | Owner | Pts | Build | Hints | Done when |
|---|---|---|---|---|---|
| **US-5.3** Gap summary | Chhanda | 2 | Plain-language gap paragraph. | Same template approach as US-4.4. | Manual |
| **US-6.1** Ranked recommendations | Pratish | 3 | "For you" tab list. | Unit test: no visited district ever appears (TC-20 in code form). | TC-20 |
| **US-6.2** Reasons | Lok | 2 | One-line reason on each card. | The engine returns `Recommendation{district, score, reason}`. | TC-19 |
| **US-6.3** Filters | Pooja | 2 | Budget, distance, season filters, defaulting to the S2 planning values. | Distance: compare provinces, or add rough lat/lng per district to the seed data. Pick one and write it down. | TC-21, TC-09 |
| **US-6.4** Less-explored labels | Pratish | 1.5 | Tag on the card + an info sheet explaining what "less explored" means. | The admin sets `lessExplored` (US-15.1). The info sheet states the rule. | TC-22 |
| **US-6.7** Helpful / not interested | Lok | 1.5 | Two buttons on each card. | Write to `recFeedback`; the engine filters out `not_interested`. | TC-24 |

Now pass `recommendedIds` into the S3 map.

---

### Sprint 6 — Weekly picks, festivals/food, journal and history (11 pts)

| Story | Owner | Pts | Build | Hints | Done when |
|---|---|---|---|---|---|
| **US-6.5** Weekly suggestions | Lok | 2 | Home tab: 3 picks that change each week. | Seed a `Random` with `year*100 + weekNumber + uid.hashCode` and pick 3 from the top 10. The same week gives the same picks; a new week gives new ones. No server needed. | TC-23 |
| **US-6.8** Festivals & food | Chhanda | 1 | Section on the district page. | The fields already exist from S1, so only admin data entry is needed. | Manual |
| **US-7.1** Journal entry | Pooja | 2 | Journal tab → new entry (district, dates, activities, story). | `JournalProvider` streams `users/{uid}/journal`. | TC-25 (text part) |
| **US-7.2** Photos | Lok | 2.5 | Add photos to an entry. | `image_picker` → compress (`flutter_image_compress`) → Storage `users/{uid}/journal/{entryId}/…`. Limit type and size per the acceptance criteria. Storage rules must also be owner-only. | TC-25 |
| **US-7.3** Edit/delete entry | Pooja | 1.5 | Edit the form and delete with confirmation (also delete the photos). | | TC-26 |
| **US-8.1** History timeline | Chhanda | 2 | Visits + journal entries sorted by date, with district/year filters. | Merge the two streams into one list of `TimelineItem`. | Manual |

---

### Sprint 7 — Postcards, statistics, badges/challenges, itinerary (14.5 pts — the heaviest sprint)

| Story | Owner | Pts | Build | Hints | Done when |
|---|---|---|---|---|---|
| **US-7.4** Digital postcard (Low) | Lok | 2.5 | Photo + district + caption → shareable image. | `RepaintBoundary` → `toImage()` → PNG → Hariyo's `share_helper.dart`. | Manual |
| **US-8.2** Past journey details | Chhanda | 1.5 | Tap a timeline item → places, activities, journal, photos, your review. | | Manual |
| **US-8.3** Travel statistics | Chhanda | 2.5 | x/77 with %, provinces covered, journeys, top category. | All computed from the existing providers; no new data. | TC-27 |
| **US-9.1** Badges & challenges | Pratish | 2.5 | Milestone badges + district challenges. | Extend Hariyo's `achievements.dart`: its `isUnlocked(visited, total)` signature becomes `isUnlocked(UserStats)`. | TC-28 |
| **US-9.2** Gap challenge (Low) | Pratish | 2 | e.g. "Visit 1 Spiritual district in Karnali". | Build it from the S4 gap data. | Manual |
| **US-9.3** Turn off gamification (Low) | Pratish | 1 | Settings switch that hides all badge/challenge UI. | `users/{uid}.gamificationOn`; wrap those widgets in an `if`. | TC-29 |
| **US-10.1** Itinerary | Pooja | 2.5 | Day-by-day plan for a district with a budget. | `users/{uid}/itineraries`. Keep it simple: a list of days, each with activities. | TC-30 |

**Risk:** if the team falls behind, the three **Low** stories (7.4, 9.2, 9.3) are the first to defer, as the proposal's risk table says. Record any deferral in the workbook rather than hiding it.

---

### Sprint 8 — Offline, safety, reviews, safety alerts (12.5 pts)

| Story | Owner | Pts | Build | Hints | Done when |
|---|---|---|---|---|---|
| **US-11.1** Save for offline | Lok | 3 | "Save for offline" on the district page and itinerary; show storage used; remove. | Firestore already caches reads offline on mobile. For an explicit save, write the district JSON plus cached images to `path_provider`'s documents directory and add up the file sizes. | TC-31 |
| **US-11.2** Use offline + sync | Lok | 3 | Offline banner listing what works; journal drafts upload on reconnect. | `connectivity_plus` for the banner. Firestore **queues writes offline automatically**, so text drafts sync on their own. Photos need a small local upload queue. | TC-32 |
| **US-12.1** Safety tips & alerts | Pratish | 1.5 | District page: emergency numbers (Police 100, Ambulance 102, Tourist Police 1144 — verify these), safety notes, active alerts. | Query `alerts` where `districtId == x` and `expiresAt > now`. | TC-33 |
| **US-12.2** Emergency check-in (Low) | Pratish | 1.5 | Save a contact; one-tap "I'm safe in {district}" message. | `url_launcher` with an `sms:` URI, so the user's own SMS app sends it. | Manual |
| **US-13.1** Reviews | Chhanda | 2 | Average rating + list; visited users can rate and review. | Rules: only allow creating a review when a visit exists (`exists(/users/$(uid)/visits/...)` — or check it in the app and note the limitation). | TC-37 |
| **US-15.6** Post safety alerts | Pooja | 1.5 | Admin form: district, message, expiry date. | Log it to `changeLog`. | TC-33 |

---

### Sprint 9 — Feedback, reports, admin analytics, moderation (13 pts)

| Story | Owner | Pts | Build | Hints | Done when |
|---|---|---|---|---|---|
| **US-14.1** App feedback | Lok | 1.5 | Rating + category + comment → `feedback`. | Reuse the layout from Hariyo's `feedback_screen.dart`, but write to Firestore instead of email. | Manual |
| **US-14.2** Report recommendation | Chhanda | 1.5 | "Report" on a recommendation card. | Same collection, `type: 'recommendation'`. | Manual |
| **US-14.3** Report wrong info | Lok | 1.5 | "Report wrong information" on the district page (cost/transport/season…). | `type: 'district_info'`. | TC-35 |
| **US-15.3** District analytics | Pratish | 3 | Admin charts: districts per province and type, less-explored count, visits per district (**totals only**). | Increment `stats/districtVisits.{id}` with `FieldValue.increment(1)` whenever a visit is added. Admins never read `users/*`. | TC-34 |
| **US-15.4** Recent changes | Pratish | 2 | `changeLog` list: newest first, with date and admin. | You've been writing it since S1, so this is only the read side. | Manual |
| **US-15.5** Feedback inbox | Pooja | 2 | Admin inbox with filters; New → Reviewed → Resolved. | | TC-36 |
| **US-15.7** Moderate reviews | Pooja | 1.5 | Admin deletes a review; the average updates; logged. | | TC-40 |

**After Sprint 9: usability testing.** Run the tasks in the *Usability Testing* sheet with at least 5 survey participants, fill in the SUS calculator (target at least 70), record task completion and open defects, and fix what you can before the final submission.

---

## 7. Team Git workflow

- **One repo** under one member's account; add the other three as collaborators.
- **Branch per story:** `feature/US-3.2-mark-visited`. Open a pull request, and another member reviews it before merging into `main`. Reviews are visible teamwork evidence.
- **Commit messages reference the story:** `US-3.2: add date picker to mark-visited flow`. Commit small and often, whenever something works.
- **Tag each sprint:** `git tag sprint-3` at the review. Your teacher can check out any sprint.
- **Never commit:** keystores (`*.jks`), service-account JSON, API keys in code.
- **Keep the workbook in step:** at the end of each sprint, update the sprint sheet (Done), the *Test Cases* results and the burndown, and link the PRs in *Feature & Module Tracking*.

---

## 8. Definition of Done (use for every story)

1. All acceptance criteria in the *agile userstory* sheet are demonstrated.
2. The related test case(s) are run and recorded with Actual result, Status, Tester and Date.
3. The code was reviewed by one other member through a PR and is merged into `main`.
4. No analyzer warnings (`flutter analyze`). Pure logic (DNA, recommender, stats) has unit tests.
5. The UI matches the Figma tokens (§5) and works on a small phone (360 px wide).
6. User data is private: Firestore and Storage rules cover any new collection.

---

## 9. Packages you will probably add

`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `google_sign_in`, `image_picker`, `flutter_image_compress`, `fl_chart`, `connectivity_plus`, `intl` (dates). Already in Hariyo: `provider`, `flutter_svg`, `path_drawing`, `xml`, `share_plus`, `url_launcher`, `path_provider`, `shared_preferences`, `google_fonts`.

Check each one on pub.dev for the current version, and its platform setup steps (iOS `Info.plist` permissions for the camera and photos).

---

*Prepared from: MyYatra Project Proposal, MyYatra_Project_Planning.xlsx (Agile Release Plan, User Stories, Test Cases, References & Assumptions) and the Hariyo Naksha source. Story owners and points are copied from the workbook; change them there first if the team re-plans.*
