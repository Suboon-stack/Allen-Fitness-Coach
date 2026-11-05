# Allen — AI Fitness Coach

**Status: Active Development — UI/UX Redesign and Functionality Improvements**

Allen is a Flutter fitness application that brings workout planning, nutrition tools, progress tracking, and Gemini-powered guidance together. Development proceeds screen by screen, combining a consistent interface with targeted functionality repairs.

## Overview

Allen helps users plan and save workouts, track activity and weight, generate meal plans, estimate nutrition from food photos, and ask an AI fitness coach questions. Firebase handles authentication; fitness records currently persist locally on the device.

The owner reviewed and approved the previous Midnight Navy + Electric Blue milestone on an Android phone, including the refined Welcome screen. The Nutrition Planner and circular Nutrition/Water trackers are now also owner-approved for this redesign-branch milestone. The AI Coach Chat UI/UX and Food Scanner implementation/UI/UX were subsequently tested and approved by the owner on Android. UI approval does not establish complete live-service, accessibility, or persistence verification.

## Tech Stack

| Area | Technologies |
| --- | --- |
| Application | Flutter, Dart, Material 3 |
| Authentication | Firebase Authentication, Firebase Core |
| State management | Bloc/Cubit for authentication; typed ChangeNotifier controllers for chat and food scanning; widget-local state for other fitness screens |
| AI integration | Google Gemini API over HTTP, including food-image analysis |
| Local persistence | SharedPreferences, local services and repositories |
| Device capabilities | Camera (embedded still-photo capture), Image Picker, Flutter Local Notifications, Path Provider |
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
| Nutrition | Meal generation, logging, summaries, and water tracking are implemented. Planner and circular Nutrition/Water trackers are redesigned and owner-approved. Meal logging validates values; water uses the labeled app default and confirmed daily totals. |
| Food Scanner | Android-tested and owner-approved: embedded camera, gallery selection, explicit photo review/analysis, Gemini nutrition estimates, editing, and confirmed saving to Nutrition Tracker. Safe failures/retry and duplicate/stale-response guards have automated coverage. |
| AI Coach | Redesigned and UI/UX-approved on Android: original sparkle header, selectable formatted replies, bounded temporary context, safe errors/Retry, and request/account/navigation guards. Automated reliability coverage; no saved conversation archive. |
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
- [x] **Nutrition** — Planner, circular Tracker/Water, and validated meal logging redesigned and owner-approved; remaining device/live-service verification is tracked separately.
- [x] **AI Coach** — Chat redesigned and UI/UX-approved on Android; merged into `main`. See [design, validation and security notes](docs/ui-ux/ai-coach-redesign.md).
- [x] **Food Scanner** — dashboard, camera and results redesigned; implementation/UI/UX tested and owner-approved on Android. See [design and validation](docs/ui-ux/food-scanner-redesign.md).
- [ ] **Progress** — upcoming.
- [ ] **Profile and Settings** — upcoming.

Checked entries indicate implemented, owner-approved UI rather than completion of the entire feature. Reviewed screens share a centralized Midnight Navy + Electric Blue Material 3 design system. Other routes retain their earlier styling until their own milestone.

See the [design system](docs/ui-ux/midnight-theme.md), [workout repair notes](docs/ui-ux/workout-repairs.md), and [UI/UX documentation index](docs/ui-ux/README.md). Design decisions are based on the owner brief and code inspection; no user research or usability-study results are claimed.

## Nutrition & Meal Planning

Nutrition has three tabs that share the Midnight Material 3 design system:

| Tab | What it does |
| --- | --- |
| **Tracker** | Shows today's recorded calories in an apple-centered progress ring, compact protein/carbohydrate/fat totals, and the actual meal list. Percentages appear only for valid saved goals belonging to the signed-in account. |
| **Planner** | Generates Gemini meal suggestions from existing goal, diet, and calorie preferences. Shows readable results, loading and retry states; retains the previous valid plan when regeneration fails. Errors never silently become canned meals. |
| **Water** | Shows today's saved milliliters in a matching drop-centered ring, with +100/+250/+500 ml actions. The 2,000 ml goal is clearly labeled as an app default, not a personalized recommendation. Home reads the same water total. |

**Logging meals:** Add Meal opens a keyboard-safe sheet for meal type, name, calories, protein, carbohydrates, and fat. Values are validated before saving. AI suggestions have a separate review-and-log action: generating a plan does not count it as food eaten. Missing AI macros require confirmation rather than invented values. Duplicate taps are guarded; confirmed meals refresh the totals immediately.

**Saving and the daily boundary:** Meals are saved locally with their date and nutrition values. Water is saved as one total per date. At local midnight the trackers switch to the new day's records; yesterday's records are retained. Refresh reloads today's saved data and goals without adding or deleting entries. Unsaved AI suggestions remain in memory and are not a saved meal-plan archive.

**Reliability:** Stable meal UUIDs, serialized mutations, native-write confirmation, and cache recovery protect against duplicate saves and lost water increments. Tests cover malformed AI output, failures/retries, actual totals, account-filtered meal reads, accessible layouts, and Home water agreement.

**Current limits:** The interface only browses today's records. Yesterday's retained data has no history/date selector yet; water has no individual-entry history or undo. Fitness records are device-local rather than cloud-synchronized, and date-only water totals are still shared across accounts on a device. Ownership migration needs a separate approved plan.

See the [design and Android checklist](docs/ui-ux/nutrition-water-trackers.md), [repair root causes](docs/ui-ux/nutrition-repairs.md), and [approved Nutrition milestone](docs/ui-ux/approved-nutrition-milestone.md). UI approval does not imply that every live API, physical-device failure or process-restart case has been verified.

## AI Coach Chat

Ask Allen provides a minimalist Midnight chat interface with an original four-point sparkle, starter suggestions that populate the composer, readable message bubbles, and selectable paragraphs/lists. The keyboard-safe composer supports bounded multiline input and an accessible send button. Scrolling follows new messages near the bottom while preserving the position of someone reading earlier replies.

**Gemini integration:** `AiService.chat` sends the fitness instructions, current question, and bounded successful conversation context to the configured Gemini REST endpoint. Only one request can be active per conversation. A 30-second timeout and response validation handle empty, malformed, blocked, or truncated output. Workout and meal generation remain on their existing paths.

**Recovery:** HTTP/provider statuses map to fixed, understandable messages. Raw exceptions, request URLs and provider details are not shown or logged by chat. Retry reuses the latest failed user message rather than adding a duplicate; an unsent composer draft is retained. Failed exchanges never become successful model context, and account changes/navigation invalidate stale replies.

**Temporary context and limits:** Chats are not saved in Allen and start fresh when reopening the screen. Gemini context keeps at most eight successful exchanges and 16,000 text units including instructions and the current question; older complete exchanges are removed as needed. Inputs are limited to 4,000 and visible replies to 12,000 text units. These bounds use UTF-16 code units, not token counts. Formatting is a small text-only subset rather than a full Markdown/web renderer. No saved history, streaming, or automatic access to personal fitness records is implemented.

**Security boundary:** Requests still originate in the mobile client. Git-ignored configuration and sanitized errors do not protect a bundled API key from extraction. Backend-mediated key management remains a separately planned architectural improvement; this milestone does not claim complete key protection.

The owner has approved the UI/UX on Android. [Design decisions and device checklist](docs/ui-ux/ai-coach-redesign.md), [repair root causes](docs/ui-ux/ai-coach-repairs.md), and [milestone validation](docs/ui-ux/approved-ai-coach-milestone.md) distinguish that approval from automated tests and remaining live-service/accessibility checks.

## AI Food Scanner

Food Scanner provides a cohesive Midnight Navy + Electric Blue flow: a minimalist entry screen, camera-first capture, photo review, and compact nutrition results. The owner tested and approved the implementation and UI/UX on an Android phone.

- **Camera or gallery:** Capture a still photo with the approved Flutter `camera` plugin, or select one using Image Picker. The embedded preview includes framing brackets, a shutter, a gallery shortcut, and lens switching when supported. Camera permission/unavailable states offer recovery; audio capture is disabled.
- **Explicit Gemini analysis:** Selecting a photo does not upload it. Review it first, then press **Analyze photo** to send it to Gemini. Results show the identified name, estimated calories/protein/carbohydrates/fat, and supported items/portion estimates only when returned. An optional AI food note is retained when available. No predefined nutrition is substituted after failure.
- **Review and edit:** Correct names, quantities and nutrition in a keyboard-safe form. Nutrition values are totals for the reviewed portion; changing quantities does not automatically recalculate them. **Apply changes** updates the review without saving a meal.
- **Save to Nutrition:** Choose an existing meal category and explicitly confirm **Save to Nutrition**. The existing local meal repository stores the reviewed values and AI provenance without a storage migration. Pending/success guards and a stable draft ID protect against duplicate saves and uncertain-write retries. **View Nutrition** reads the saved meal and matching totals, with an **AI Estimate · reviewed** label.
- **Recovery:** A 30-second timeout, structured provider/HTTP error handling, image/response validation and explicit retry cover failed requests. Overlapping analysis is blocked; navigation, account changes and newer selections invalidate stale responses. Scanner errors do not expose raw provider exceptions, request URLs or credentials.

**Limits:** Nutrition estimates can be inaccurate and are not verified nutrition measurements. JPEG, PNG and WebP images up to 8 MB after selection processing are supported; unsupported or unreadable images need another selection. Unsaved scans are temporary. There is no persisted photo archive or Recent Scans history; confirmed meals use existing account-owned device-local records. Changing a portion is not an automatic nutrition calculation. External Gemini availability/quota and device camera behavior still vary; owner approval does not certify every failure, device, accessibility or process-restart case.

**Client-side key risk:** Food analysis uses the existing direct mobile-to-Gemini architecture. The bundled API key can be extracted even though local credentials are git-ignored and errors are sanitized. A server-side gateway and stronger credential management remain future work.

The milestone has 63 scanner tests; the full suite has 305 passing tests. Mock camera/HTTP/storage coverage is distinct from the owner's Android review. See the [case study, validation and Android checklist](docs/ui-ux/food-scanner-redesign.md) and [repair root causes](docs/ui-ux/food-scanner-repairs.md).

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

Current Midnight screenshots have not been added. Place actual Android captures in `docs/ui-ux/screenshots/`, for example `welcome-motion-midnight.png`, `midnight-home.png`, `midnight-workout-plan.png`, and `midnight-saved-workouts.png`. Food Scanner captures can use `midnight-food-scanner.png`, `midnight-food-camera.png`, and `midnight-food-result.png`; no current scanner captures have been supplied to the repository. Follow the [screenshot checklist](docs/ui-ux/screenshot-checklist.md), record the device/build, and remove personal information. No mockups or AI-generated images are used as implementation evidence.

## Known Issues

- Local fitness/profile data is not consistently isolated per account. Nutrition meal reads now filter existing owner IDs; water and raw Progress statistics still have shared-data limitations. A separate ownership/migration plan is needed; no existing records are migrated or deleted.
- Weight records lack stable IDs for reliable individual deletion; the Settings clear-weight action also uses a legacy storage path.
- Quote failures can still use predefined fallbacks. Workout/meal generation, AI Coach Chat and Food Scanner report failures explicitly; the quote fallback remains separate.
- Food-image nutrition is an estimate, not independently verified data. No saved photo/scan archive is implemented; the Gemini key remains extractable from the client until a backend gateway is introduced.
- Recurring daily reminders are not implemented.
- The registration name is collected but not persisted by the authentication repository.
- Workout history retains the existing latest-50 limit. Live Gemini output, real app-restart persistence, TalkBack, and full authentication flows need further device verification.
- Full-project analysis reports existing diagnostics in Profile, Progress, Settings, and the Progress repository. Current Nutrition checks are recorded in the [approved Nutrition milestone](docs/ui-ux/approved-nutrition-milestone.md); the previous approved milestone has a separate [release review](docs/ui-ux/approved-midnight-milestone.md).

The dashboard statistics-source mismatch and workout completion UUID bug have targeted fixes and regression coverage. Their root causes and scope are documented separately from visual decisions.

## Getting Started

Android is the current build/review target. Use Flutter 3.41 or newer with Dart 3.11 or newer (the current dependency lock minimums), Android SDK with an API 24+ target device, and a Java 17 toolchain. The Firebase CLI and FlutterFire CLI are needed to configure your own Firebase project.

Use `main` for the approved milestones; feature branches are retained for their review history.

```bash
git clone https://github.com/Suboon-stack/Allen-Fitness-Coach.git
cd Allen-Fitness-Coach
git switch main
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

Tests use test doubles and isolated storage; they do not prove live Firebase/Gemini availability or exercise real user records. See the [Food Scanner case study and validation](docs/ui-ux/food-scanner-redesign.md), [AI Coach milestone review](docs/ui-ux/approved-ai-coach-milestone.md), [Nutrition milestone](docs/ui-ux/approved-nutrition-milestone.md), and [earlier UI milestone](docs/ui-ux/approved-midnight-milestone.md) for executed results and remaining manual checks.

## Development Notes

Allen is being improved as a Flutter development and UI/UX portfolio project. Reviewable screen-level milestones demonstrate practical UI implementation, API integration, state management, persistence, testing, and documented design decisions while preserving existing user data and accurately reporting remaining work.
