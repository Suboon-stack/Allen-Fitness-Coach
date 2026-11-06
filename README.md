# Allen — AI Fitness Coach

Allen is a Flutter fitness app for planning workouts, tracking nutrition and weight, and getting AI-powered guidance. It combines Firebase Authentication, Google Gemini integration, local persistence, and a consistent Midnight Navy + Electric Blue interface.

## App screenshots

Real Android screenshots captured from Allen with test-account data.

<p align="center">
  <img src="screenshots/new_ui/home.png" width="180" alt="Allen Home Dashboard" />
  <img src="screenshots/new_ui/workout.png" width="180" alt="Workout Planner" />
  <img src="screenshots/new_ui/nutrition.png" width="180" alt="Nutrition Tracker" />
</p>
<p align="center">
  <img src="screenshots/new_ui/water.png" width="180" alt="Water Tracker" />
  <img src="screenshots/new_ui/ai_coach.png" width="180" alt="AI Coach Chat" />
  <img src="screenshots/new_ui/food_scanner.png" width="180" alt="AI Food Scanner" />
</p>
<p align="center">
  <img src="screenshots/new_ui/progress.png" width="180" alt="Progress Tracking" />
  <img src="screenshots/new_ui/profile.png" width="180" alt="Profile Overview" />
  <img src="screenshots/new_ui/settings.png" width="180" alt="App Settings" />
</p>

## Key features

- **Workouts:** Gemini-generated plans, saved workouts, and completion tracking.
- **Nutrition:** Meal suggestions, reviewed meal logging, daily summaries, and water tracking.
- **Food Scanner:** Camera/gallery input, Gemini nutrition estimates, editing, and confirmed saving to Nutrition.
- **AI Coach:** Temporary chat with bounded context, loading feedback, safe errors, and retry.
- **Progress:** Interactive weight charts, date filters, weight logging/editing, and an activity timeline.
- **Account:** Email/password sign-in, password reset, account-scoped profiles, and local JSON export.
- **Navigation:** Home, Workout, Nutrition, Progress, and Profile destinations.

## Tech stack

| Area | Technologies |
| --- | --- |
| Mobile UI | Flutter, Dart, Material 3 |
| Authentication & AI | Firebase Authentication, Google Gemini REST API, HTTP |
| State & storage | Bloc/Cubit, ChangeNotifier, SharedPreferences |
| Device features | Camera, Image Picker, Flutter Local Notifications, Path Provider |
| Charts & testing | FL Chart, Flutter Test |

## Architecture

Authentication uses `AuthCubit` and `AuthRepo`. Chat and scanning use typed ChangeNotifier controllers; other screens retain local widget state. Models, repositories, and services separate presentation from persistence and external integrations. Fitness records are stored locally; Firebase manages sign-in, without Firestore fitness-data synchronization. Unit and widget tests cover authentication, AI failures, persistence, account transitions, and navigation.

## Getting started

**Requirements:** Flutter 3.41+, Dart 3.11+, Android SDK, Java 17, Firebase CLI, and an Android device/emulator running API 24+.

```bash
git clone https://github.com/Suboon-stack/Allen-Fitness-Coach.git
cd Allen-Fitness-Coach
flutter pub get
```

1. Create a Firebase project, enable **Email/Password** authentication, and register the Android app as `com.example.allen`. Configure it with:

   ```bash
   dart pub global activate flutterfire_cli
   firebase login
   flutterfire configure --platforms=android
   ```

   Ensure the generated `lib/firebase_options.dart` and `android/app/google-services.json` exist. Sanitized examples are included in the repository.
2. Copy `lib/secrets.example.dart` to `lib/secrets.dart` and replace the placeholder with your own Gemini API key. Keep real keys and local Firebase configuration uncommitted.
3. Connect an Android device/emulator, then run `flutter devices` and `flutter run -d <device-id>`.

To validate locally, run `flutter analyze`, `flutter test`, and `flutter build apk --debug`.

## Project status & known limitations

**Active development — UI/UX and functionality improvements.** The redesigned feature milestones are merged into `main`; live-service, device, and accessibility regression testing remains ongoing.

- Gemini suggestions and photo nutrition are estimates. Client-side API keys remain extractable; a protected backend is a future security improvement.
- Fitness data and exports are local and not additionally encrypted or cloud-synchronized. Exports stay in app-private storage; external sharing is not implemented.
- Account isolation is incomplete: water is shared device data, and older workout paths retain ownership limitations. Unowned legacy profiles/weights are preserved but excluded from personal summaries; exports omit foreign/unowned records.
- Account deletion removes Firebase access, not local fitness records. The legacy cache-clear action does not clear current weight history.
- Chat history is temporary. Notifications support Android permission/status checks and an explicit test; daily reminders are not scheduled. Theme, units, and language are currently fixed.
