> Historical Stage 1 record. Later approved changes supersede the statuses and deferred fixes below; see the [current milestone](approved-midnight-milestone.md) and [Midnight design system](midnight-theme.md).

# Screen inventory

Inventory from existing Dart source. Only Home and its drawer are redesigned in Stage 1.

| Screen / presentation | Existing behavior | Stage 1 |
| --- | --- | --- |
| IntroGate / IntroPage | Intro, auth-state gate, auth errors/loading | Unchanged |
| AuthPage | Login/registration toggle | Unchanged |
| LoginPage | Email/password login; password reset dialog | Unchanged |
| RegisterPage | Name/email/password/confirmation | Unchanged |
| HomePage | Daily motivation, saved activity, feature links, drawer | Redesigned |
| ChatPage | Gemini coach conversation, welcome and loading | Unchanged |
| WorkoutPage | Muscle/level/duration selection, generation, save/complete, history | Unchanged |
| MealPlannerPage | Tracker, AI planner, water tabs; nutrition and meal logging | Unchanged |
| CalorieScannerPage | Camera/gallery sheet, preview, Gemini nutrition analysis | Unchanged |
| ProgressPage | Overview/weight/stats, weight dialog and charts | Unchanged |
| ProfilePage | Account/profile editing and nutrition targets | Unchanged |
| SettingsPage | Reminders, export, clear weight logs, logout/delete account | Unchanged |
| AboutPage | Product and technology information | Unchanged |

## Architecture and navigation

Main initializes Firebase and notifications, provides AuthCubit, then displays IntroGate. AuthPage switches between login and register locally. Authentication uses AuthRepo/FirebaseAuthRepo. Home pushes existing feature pages with Navigator and provides all feature/account destinations through a scrollable drawer. Back returns to Home without another navigation layer.

Fitness screens retain StatefulWidget state and their repositories. UserRepository, WorkoutRepository, MealRepository, and ProgressRepository currently use LocalStorageService/SharedPreferences. StorageService is a separate legacy data path used by Home and settings. Firestore dependency/model serializers exist, but these repositories do not currently use Firestore collections. AiService handles Gemini requests and chat history; NotificationService handles reminders. No service, repository interface, credential, or storage schema was modified.

## Files in this stage

Modified: `lib/fitness/theme/app_theme.dart`, `lib/fitness/pages/home_page.dart`, `lib/main.dart`, `test/widget_test.dart`.

Added: `lib/fitness/widgets/allen_components.dart`, `docs/ui-ux/design-system.md`, `docs/ui-ux/redesign-decisions.md`, `docs/ui-ux/screen-inventory.md`.

## Profile & Settings milestone — current additions (6 November 2026)

This section supersedes the historical Stage 1 statuses above for these routes.

| Route/component | Current implementation |
| --- | --- |
| ProfilePage | Real identity, owned statistics, saved goal, details/BMI/targets; reference layout, UI/functionality owner-approved |
| ProfileEditor | Validated optional personal details/targets; UID-owned save; no automatic weight-history insertion |
| SettingsPage | Fixed appearance/units/language, Android notification permission/status/test, system motion information |
| AccountSecurityPage | Authenticated email, password-reset email, sign out and unchanged existing Firebase deletion operation |
| DataPrivacyPage | Local-data disclosures, account-filtered app-private JSON export, unchanged older-cache clear operation |
| AboutPage | Concise app/version, AI and local-data explanation |
| FeatureNavigation | Five destinations on Home, Workout, Nutrition, Progress and Profile; nested Profile routes highlight Profile |

No new dependencies or water migration. Profile keys are additive and UID-specific; global legacy data is preserved. Existing Cubit, repositories and Navigator routes remain. See the [case study](profile-settings-redesign.md).
