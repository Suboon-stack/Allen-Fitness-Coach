# Allen — AI Fitness Coach

**Status: Active Development — UI/UX Redesign and Functionality Improvements**

Allen is a Flutter fitness application that brings workout planning, nutrition tools, progress tracking, and Gemini-powered guidance together. Development proceeds screen by screen, combining a consistent interface with targeted functionality repairs.

## Overview

Allen helps users plan and save workouts, track activity and weight, generate meal plans, estimate nutrition from food photos, and ask an AI fitness coach questions. Firebase handles authentication; fitness records currently persist locally on the device.

The owner has reviewed and approved the latest Midnight Navy + Electric Blue UI on an Android phone, including the refined Welcome screen. UI approval does not establish complete live-service or persistence verification.

## Tech Stack

| Area | Technologies |
| --- | --- |
| Application | Flutter, Dart, Material 3 |
| Authentication | Firebase Authentication, Firebase Core |
| State management | Bloc/Cubit for authentication; widget-local state for fitness screens |
| AI integration | Google Gemini API over HTTP, including food-image analysis |
| Local persistence | SharedPreferences, local services and repositories |
| Device capabilities | Image Picker, Flutter Local Notifications, Path Provider |
| Charts and utilities | FL Chart, Intl, UUID |
| Testing | Flutter Test, mock HTTP responses, isolated preference storage |

Cloud Firestore is a dependency and appears in model serializers; current fitness repositories use local storage rather than Firestore synchronization.

## Features

| Feature | Implementation and verification |
| --- | --- |
| Authentication | Email/password registration, login, password reset, session restoration, logout, and account deletion. Automated state/validation coverage; live Firebase flows require further verification. |
| Home Dashboard | Compact activity summaries, feature shortcuts, coach entry, bottom navigation, refresh and recovery states. UI approved on Android; summaries use existing repositories. |
| Workout Planner | Focus, difficulty and duration preferences; Gemini generation; compact exercise details; save and completion actions. Explicit generation failures and retry replace silent workout fallbacks. |
| Saved Workouts | Ready/completed filters, expandable details, completion, and confirmed deletion. UUID, duplicate-action and persistence-failure regression tests; full device/restart verification remains pending. |
| Nutrition | Meal generation, meal logging, nutrition summaries, and water logging are implemented. Redesign and reliability verification are upcoming. |
| Food analysis | Camera/gallery selection and Gemini nutrition estimates are implemented. Error/result handling needs improvement. |
| AI Coach | Gemini conversation and in-session history are implemented. Interface and error handling improvements are upcoming. |
| Progress | Weight logging, charts, and activity summaries are implemented. Weight deletion and account data separation have known limitations. |
| Profile and Settings | Profile editing, BMI, nutrition targets, JSON export, and account controls are implemented; redesign and further verification are upcoming. |
| Reminders | Immediate notifications and an enable preference exist; recurring daily scheduling is not implemented. |

“Implemented” describes code present, not a guarantee that every device or live-service flow is verified. AI output requires user judgment.

## UI/UX Redesign Progress

- [x] **Welcome Screen** — redesigned; custom blue movement graphic and capitalized Allen wordmark.
- [x] **Login and Registration** — redesigned, including shared password-reset styling; further live authentication verification remains pending.
- [x] **Home Dashboard** — redesigned; compact layout, two-column statistics, and navigation retained.
- [x] **Workout Planner** — redesigned; generation, saving, completion, and failure handling have automated coverage.
- [x] **Saved Workouts** — redesigned, pending full functionality verification on device.
- [ ] **Nutrition** — upcoming.
- [ ] **AI Coach** — upcoming.
- [ ] **Progress** — upcoming.
- [ ] **Profile and Settings** — upcoming.

Checked entries indicate implemented, owner-approved UI rather than completion of the entire feature. Reviewed screens share a centralized Midnight Navy + Electric Blue Material 3 design system. Other routes retain their earlier styling until their own milestone.

See the [design system](docs/ui-ux/midnight-theme.md), [workout repair notes](docs/ui-ux/workout-repairs.md), and [UI/UX documentation index](docs/ui-ux/README.md). Design decisions are based on the owner brief and code inspection; no user research or usability-study results are claimed.

## Current Development

- Consistent UI/UX design and reusable components.
- Improving Flutter architecture within the existing Cubit/repository structure.
- Better navigation and responsive layouts.
- Targeted functionality repairs and clearer errors.
- Gemini API reliability and response validation.
- Data persistence and account data separation.
- Automated testing, accessibility, and device verification.

## Screenshots

Genuine captures of earlier application versions are available under [`docs/screenshots/`](docs/screenshots/) and [`docs/ui-ux/screenshots/`](docs/ui-ux/screenshots/). They are historical references, not screenshots of the approved Midnight UI.

Current Midnight screenshots have not been added. Place actual Android captures in `docs/ui-ux/screenshots/`, for example `welcome-motion-midnight.png`, `midnight-home.png`, `midnight-workout-plan.png`, and `midnight-saved-workouts.png`. Follow the [screenshot checklist](docs/ui-ux/screenshot-checklist.md), record the device/build, and remove personal information. No mockups or AI-generated images are used as implementation evidence.

## Known Issues

- Local fitness/profile data is not consistently isolated per account. A separate ownership/migration plan is needed; this milestone does not migrate or delete records.
- Weight records lack stable IDs for reliable individual deletion; the Settings clear-weight action also uses a legacy storage path.
- Meal-generation and quote failures can still use predefined fallbacks. Workout generation now reports failures explicitly; other AI flows need further review.
- Recurring daily reminders are not implemented.
- The registration name is collected but not persisted by the authentication repository.
- Workout history retains the existing latest-50 limit. Live Gemini output, real app-restart persistence, TalkBack, and full authentication flows need further device verification.
- Full-project analysis reports existing diagnostics in unreviewed nutrition/profile/progress/settings code. Current milestone validation is recorded in the [release review](docs/ui-ux/approved-midnight-milestone.md).

The dashboard statistics-source mismatch and workout completion UUID bug have targeted fixes and regression coverage. Their root causes and scope are documented separately from visual decisions.

## Getting Started

Android is the current build/review target. Install Flutter with a compatible Dart 3 SDK, Android SDK, and Java 17 toolchain. The Firebase CLI and FlutterFire CLI are needed to configure your own Firebase project.

```bash
git clone https://github.com/Suboon-stack/Allen-Fitness-Coach.git
cd Allen-Fitness-Coach
git switch redesign/performance-studio-auth
flutter doctor
flutter pub get
```

1. Create a Firebase project, enable **Email/Password** authentication, and register the Android application ID `com.example.allen`.
2. Configure your project:

   ```bash
   dart pub global activate flutterfire_cli
   firebase login
   flutterfire configure --platforms=android
   ```

   Ensure `lib/firebase_options.dart` and `android/app/google-services.json` contain your project configuration. Sanitized examples are provided as `lib/firebase_options.example.dart` and `android/app/google-services.example.json`; examples alone do not connect to Firebase.
3. Create local Gemini configuration:

   ```bash
   cp lib/secrets.example.dart lib/secrets.dart
   ```

   Replace the placeholder with your own Gemini API key. Real credentials and local project configuration are git-ignored and must remain uncommitted. Gemini requests currently originate in the client; stronger key protection remains a production-hardening task.
4. Connect an Android device or start an emulator:

   ```bash
   flutter devices
   flutter run -d <android-device-id>
   ```

Validation and local debug build:

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Tests use test doubles and isolated storage; they do not prove live Firebase/Gemini availability or exercise real user records. See the [milestone review](docs/ui-ux/approved-midnight-milestone.md) for actual results and remaining manual checks.

## Development Notes

Allen is being improved as a Flutter development and UI/UX portfolio project. Reviewable screen-level milestones demonstrate practical UI implementation, API integration, state management, persistence, testing, and documented design decisions while preserving existing user data and accurately reporting remaining work.
