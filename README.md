# Allen — AI Fitness Coach

**Status: Active Development — UI/UX Redesign & Functionality Improvements**

Allen is a Flutter-based AI fitness application that brings workout planning, nutrition tools, progress tracking, and conversational guidance together. It is currently undergoing a screen-by-screen UI/UX redesign and targeted functionality improvements, with a focus on usability, maintainability, and reliability.

## Project Overview

Allen helps users create workout and meal plans, estimate nutrition from food photos, record activity, and ask a Gemini-powered fitness coach questions. Firebase handles authentication; fitness records currently persist locally on the device.

The compact Home Dashboard has been reviewed and approved after testing on an Android phone. That approval covers its UI; remaining feature and live-service verification is tracked separately.

## Technologies

| Area | Implementation |
| --- | --- |
| Application | Flutter, Dart, Material 3 |
| Authentication | Firebase Authentication and `firebase_core` |
| State management | `flutter_bloc` / `AuthCubit`; widget-local state for fitness screens |
| AI integration | Google Gemini API over HTTP, including food-image analysis |
| Persistence | SharedPreferences through local services and repositories |
| Device tools | `image_picker`, `flutter_local_notifications`, `path_provider` |
| Charts and utilities | `fl_chart`, `intl`, `uuid` |
| Tests | `flutter_test`, repository test doubles, SharedPreferences test storage |

Cloud Firestore is a dependency and appears in model serializers, but the current fitness repositories use **local storage**, not Firestore synchronization.

## Features

| Feature | Current status |
| --- | --- |
| Home Dashboard | Redesigned and UI-approved on Android. Repository-backed workout, weight, streak, and water summaries; coach entry; feature shortcuts; refresh and recovery states. Covered by widget/regression tests. |
| Authentication | Email/password registration, login, password reset, session restoration, logout, and account deletion are implemented. State-recovery tests pass; live Firebase flows still require integration verification. |
| AI Coach | Gemini conversation with in-session history is implemented; improved response formatting, error handling, and retry UX remain planned. |
| Workout planning | Generation, saving, and history are implemented. Completion has a confirmed identifier bug; parsing needs hardening. |
| Nutrition | Meal generation, meal logging, nutrition summaries, and water logging are implemented. Further reliability and device verification remain pending. |
| Food analysis | Camera/gallery selection, image preview, and Gemini nutrition estimates are implemented. Error/result handling needs improvement. |
| Progress | Weight logging, charts, and activity summaries are implemented. Weight deletion and account data separation have known limitations. |
| Profile and settings | Profile editing, BMI, nutrition targets, JSON export, and account controls are implemented. Further redesign and verification remain pending. |
| Reminders | Immediate notifications and an enable preference exist; recurring daily scheduling is not implemented. |

“Implemented” describes code present in the repository, not a claim that every live service or device flow has been verified.

## Current Development

- Modernizing the application's UI/UX.
- Building a consistent design system.
- Improving navigation and responsive layouts.
- Redesigning individual feature screens.
- Investigating and fixing functionality issues.
- Improving error handling and application reliability.
- Adding relevant tests.
- Documenting the UI/UX design process.

## UI/UX Redesign Progress

- [x] **Home Dashboard:** compact redesign approved after Android UI testing; remaining functionality verification is tracked separately.
- [ ] **Authentication:** initial intro, login, registration, and reset redesign implemented; further login refinement, final review, and live Firebase verification remain pending.
- [ ] **Workout Planner:** pending redesign.
- [ ] **Nutrition:** pending redesign.
- [ ] **AI Coach:** pending redesign.
- [ ] **Progress:** pending redesign.
- [ ] **Profile and Settings:** pending redesign.

Home retains forest-green/mint themes. Authentication has a separate Performance Studio visual language while the design system is being refined. Other feature pages retain their existing presentation until reviewed individually.

See the [dashboard design decisions](docs/ui-ux/dashboard-refinement.md), [separate dashboard repairs](docs/ui-ux/dashboard-data-fixes.md), and [UI/UX documentation index](docs/ui-ux/README.md).

## Screenshots

A screenshot of the **approved compact Home Dashboard** has not yet been added. Place an actual Android capture at:

```text
docs/screenshots/approved/home-dashboard.png
```

[Capture guidance](docs/screenshots/approved/README.md) explains what to include. The existing `docs/screenshots/home.png` shows an earlier dashboard and is not presented as the current approved design. No mockups or AI-generated images are used as proof of implementation.

## Known Issues / Planned Improvements

- Workout completion passes an exercise name where the repository expects a saved workout ID.
- Weight records lack the stable IDs needed for reliable individual deletion. The settings weight-clear action also targets a legacy storage path.
- Local fitness/profile data is not consistently isolated per account. Any migration or ownership change needs a separate plan; this milestone does not delete or migrate records.
- Gemini workout/meal errors can silently produce predefined fallback plans. Workout parsing and food-analysis error presentation need hardening.
- Daily reminders currently show notifications immediately rather than scheduling recurring delivery.
- The registration name is collected but is not yet persisted by the authentication repository.
- Remaining feature screens need responsive UI, asynchronous-state, accessibility, and live-service verification. Full-project analysis still reports existing diagnostics in those files.

The dashboard's legacy-statistics-source mismatch and quote-blocked activity loading have been corrected. Those repairs have regression coverage and are documented separately from the UI changes.

## Getting Started

Android is the current build/review target. Use a recent Flutter SDK with Dart 3, an Android SDK and device/emulator, and a compatible Java toolchain (the Android project targets Java 17). Firebase CLI and FlutterFire CLI are needed to configure your own Firebase project.

```bash
git clone https://github.com/Suboon-stack/Allen-Fitness-Coach.git
cd Allen-Fitness-Coach
git switch redesign/performance-studio-auth
flutter doctor
flutter pub get
```

1. Create or select a Firebase project and enable **Email/Password** in Firebase Authentication. Configure its Android app for the current application ID, `com.example.allen`.
2. Configure Firebase using your own account/project:

   ```bash
   dart pub global activate flutterfire_cli
   firebase login
   flutterfire configure --platforms=android
   ```

   Ensure `lib/firebase_options.dart` and `android/app/google-services.json` contain your project's configuration. Sanitized examples are provided in `lib/firebase_options.example.dart` and `android/app/google-services.example.json`; the examples alone do not connect to Firebase.
3. Create the local Gemini configuration:

   ```bash
   cp lib/secrets.example.dart lib/secrets.dart
   ```

   Replace the placeholder with your own Gemini API key. Keep real keys and project-specific configuration out of commits. The local files above are git-ignored. The current client calls Gemini directly; stronger API-key protection is a planned production-hardening task.
4. Run on Android:

   ```bash
   flutter devices
   flutter run -d <android-device-id>
   ```

For checks and a local debug build:

```bash
dart format lib/fitness/pages/home_page.dart lib/fitness/theme/app_theme.dart lib/fitness/widgets/allen_components.dart lib/main.dart test/widget_test.dart
flutter analyze
flutter test
flutter build apk --debug
```

Tests use test doubles and local test storage; they do not establish live Firebase login or Gemini availability. See [dashboard validation notes](docs/ui-ux/dashboard-refinement.md) for the milestone's executed checks and remaining manual checks.

## Development Notes

Allen is being improved as a Flutter development and UI/UX portfolio project. Work proceeds through reviewable screen-level milestones, preserving the existing Cubit/repository architecture and documenting confirmed defects separately from presentation decisions. The goal is to demonstrate practical Flutter engineering, API integration, testing, and thoughtful interface design without overstating completion or inventing research results.
