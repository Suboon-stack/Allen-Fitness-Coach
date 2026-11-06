# Profile & Settings — owner-approved milestone

## Brief and reference

The owner approved Profile Overview, App Settings and Account & Security from `Profile Settings Redesign Trio.png`, with Allen's Midnight Navy + Electric Blue palette. The reference is a layout concept, not evidence of implemented features or user research. This milestone also includes working Data & Privacy and About routes.

The owner explicitly approved UID-specific profile storage/shared target readers, limited notification repair and five-destination navigation. No dependencies, authentication providers or backend infrastructure were added. The owner reviewed and approved the UI and functionality for GitHub finalization on 6 November 2026. The approved feature branch is `feature/profile-settings-redesign`, targeting `main`. No detailed device/live-service test outcomes or current screenshots were supplied, so owner approval is distinguished from specific automated and manual evidence.

## Original problems and decisions

| Original implementation | Decision and resulting behavior |
| --- | --- |
| Dense profile editing mixed with overview; absent goals and nutrition targets displayed as defaults. | Separate centered identity/compact statistics from a dedicated details editor. Display only saved goals/targets; unset information stays unset. |
| Profile workout count and streak used shared totals. | Read exact-owner completed workouts using the existing Progress projection. Home's existing count/streak repository methods now use that same projection. No workout schema change. |
| Global profile key could return another account's details. | UID-specific keys, verified legacy fallback, authenticated read/write checks and serialized mutations. See the separate repair record. |
| Settings implied that daily reminders were active, although alerts were immediate. | Show Android permission/status, explicit permission request and a test notification. Never represent these as scheduled daily reminders. |
| Raw export included other accounts' records and profile serialization used Firestore timestamps. | Filter exact owner IDs and serialize JSON-native local records. Clearly label the destination as app-private storage. |
| Reference includes unsupported security/customization controls. | Retain layout hierarchy while omitting fake protection claims, MFA, device counts and inactive switches. |
| Four-tab navigation existed only on some destinations. | Share Home / Workout / Nutrition / Progress / Profile across the existing routes; keep the drawer and feature links. |

## Components and layout

- **Identity:** centered 88 px initials avatar, real local profile name or Firebase display-name fallback, and authenticated email. No photo-edit badge without photo-edit functionality. No mockup account values.
- **Statistics:** three compact panels for completed workouts, latest dated weight and a workout-date streak. A dash denotes unavailable weight/data; zero completion count is shown only after a successful read. Streak uses consecutive distinct recorded workout dates ending today or yesterday. Saved workouts do not store a separate completion timestamp, so this is not an exact history of when completion buttons were pressed.
- **Goal:** a genuine saved goal, or an explicit setup entry. Personal details retain age, gender, height, profile body weight, BMI/category and nutrition targets. BMI uses profile measurements; the editor explains that dated weight logging belongs to Progress. BMI is a general screening measure, not a diagnosis.
- **Settings groups:** navy Material surfaces with dividers, secondary-blue leading icons and minimum Material touch targets. Theme, accent, Metric and English are informational. Android permission is the notification source of truth across reopen/restart; there is no new app preference claiming a schedule. Motion follows system accessibility preferences.
- **Account & Security:** neutral account-management introduction, authenticated email, explicit reset-email action and sign out. Reset has pending/duplicate guards and a 30-second UI timeout; results are ignored after account changes/disposal. AuthCubit retains Firebase session reconciliation and sanitized errors.
- **Data & Privacy:** account-filtered JSON export, local/cloud boundaries and plain-language limits. Existing account-deletion and older `weight_logs` cache-clear operations remain available under separate disclosure/confirmation controls with their original effects. No current-history purge, local account cleanup or new bulk-deletion behavior was introduced.
- **About:** concise app/version/AI-data explanation using existing branding and the shared theme.
- **Tokens:** existing centralized colors, typography, 20 px page padding, 8/16/24 px spacing and 12 px grouped-surface corners. No new palette, gradients, shadows or packages.

## Flow and navigation

Home → Profile → Personal details / Account & Security / Settings / Data & Privacy / About.

All five primary destinations use one shared NavigationBar. Existing routes remain Navigator-based. Tapping a destination already on the route stack returns to that instance and keeps its state (for example, the Workout Saved tab). Routes popped on return are disposed; this is not an always-retained five-tab IndexedStack. Nested Profile pages highlight Profile and return to the overview when it already exists. Workout save actions remain above its bottom navigation.

## Accessibility and reliability

Responsive scrollable content is constrained to the existing content/form widths. Compact statistics reflow on narrow screens or large text. At large text the navigation labels show the selected destination while all destinations keep semantic labels. Forms respect SafeArea/keyboard insets, permit keyboard dismissal while scrolling and scroll to invalid fields. Read-only settings have no misleading chevrons or switches.

Profile data resets on account change. Read epochs, keyed account boundaries, mounted checks and current-owner checks prevent stale reads/acknowledgments from becoming another account's UI. Forms retain values on validation/storage errors and block duplicate saves. Native write acknowledgment and cache recovery avoid presenting failed SharedPreferences writes as saved.

## Compatibility and privacy

New profile writes use `user_profile_<URI-encoded Firebase UID>` with the existing fields and ISO timestamps. The global `user_profile` remains byte-for-byte untouched; its `id` must match before it can supply a fallback. Editing a verified legacy profile creates an owned copy, preserving creation metadata/unknown fields in that copy. Unowned records are never claimed. Nutrition and Progress target readers use the same UID lookup. No water or weight-history migration occurs.

Profile/export reads and writes require the live authenticated UID in UserRepository. Queued mutations recheck ownership; an already-submitted native write may finish under its original UID, but cannot be redirected to the next account or acknowledged in that account's UI. This is local application isolation, not encryption or server-side access control.

Personal export includes only matching-owner profile/workouts/meals/weights. Shared water, foreign/unowned records and temporary AI context are excluded. Existing storage records are not mutated. UUID export filenames prevent overwriting an earlier account's export; a detected stale/incomplete export is cleaned up independently of source records. The file remains in app-private Documents storage, without a new sharing/download dependency. External sharing, encryption, import and cloud backup are not implemented. Sign out does not erase local fitness records or earlier exports.

Known remaining limitations:

- Water remains shared, date-keyed device data; ownership migration is deferred.
- Older workout-list/mutation paths retain legacy ownership limitations; fixing statistics/export does not constitute a complete workout privacy repair.
- Unowned legacy profiles/weights are preserved but excluded from personal summaries/export.
- Firebase name update is best-effort after account creation; failed supplementary metadata must not falsely report failed registration. Existing names are not reconstructed automatically. The owned local profile editor provides another explicit name source.
- Daily notification scheduling, customizable themes/accents/units/languages, app haptic preferences, avatar upload, email changes, MFA and device management are deferred.
- Firebase account deletion keeps its existing effect; local fitness records are not purged. The old cache-clear operation removes only `weight_logs`, not current `weights` history.
- Client-side Gemini keys remain extractable; a protected backend gateway is a future architecture task. Gemini requests and scanner/chat behavior are unchanged here.

## Validation and evidence

Validation performed on 6 November 2026:

| Check | Actual result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed` on changed/new Dart files | Passed: 27 files, 0 changes required |
| `flutter analyze --no-pub` | Passed: no issues; 0 errors, warnings or infos. The previous milestone recorded 7 existing diagnostics in Profile/Settings; those are removed. |
| `flutter test --no-pub` | Passed: 395 tests, including 45 new milestone tests; no failures |
| `flutter build apk --debug --no-pub` | Passed: `build/app/outputs/flutter-apk/app-debug.apk` (`assembleDebug`, 13.1 seconds) |
| `git diff --check` | Passed |
| Changed-file credential/generated-file review | No credential-pattern findings or generated/environment files included |

Tests cover UID switching, legacy preservation, owned-key mismatch, edit identity/creation-date preservation, optional fields, native write failures, queued/stale operations, JSON/account-filtered export with actual temporary-file writes, registration names, notification method-channel behavior, password reset/sign-out states, route reuse and empty/loading/error UI. Fixtures cover 320×568, 390×844 and 800×400 layouts at 200% text, plus a keyboard-inset editor. They are not physical-device, real process-restart or live Firebase evidence.

Finalization review: all 33 changed files match the approved milestone inventory. Formatting made no Dart changes. The repository credential-pattern scan found no exposed keys/private credentials; ignored local configuration and generated APK/build outputs are excluded. AuthCubit, Gemini service, dependencies, water persistence, the Firebase deletion implementation and the legacy cache-clear implementation remain unchanged.

SDK: `/home/suboon/flutter/bin/flutter`; Android SDK: `/home/suboon/Android/Sdk`. Dependencies and Android configuration are unchanged. Gemini service, AuthCubit, water persistence and legacy StorageService implementations are unchanged.

Owner approval of the UI and functionality is recorded above. Specific notification-delivery, reset-email, process-restart, TalkBack and device-matrix results have not been supplied; the checklist below remains a targeted regression/capture guide. Follow the [screenshot checklist](screenshot-checklist.md). Do not present the approved mockup or test data as an application screenshot.

## Android regression and capture checklist

1. Install the debug APK as an update, or run the app on a connected Android device. Existing app data should remain; no reinstall/clear-data step is required.
2. Confirm real identity/initials and owned statistics. Edit optional details, goal and nutrition targets; reopen the app and verify persistence. Check that Nutrition/Progress use the saved targets. BMI uses profile measurements, separately from dated check-ins.
3. Switch between two test accounts. Each must keep its own profile/targets/history/statistics; an open editor or pending operation must not expose the previous account's details. Unowned legacy records stay excluded and retained.
4. Send a password-reset email and verify actual inbox delivery; check offline errors and sign out/back navigation. Use a non-destructive test flow; no new local-data deletion flow is part of this milestone.
5. In Settings, check denied/allowed notification states, the Android prompt, explicit test delivery, Android Settings return and app restart. Daily scheduling must never be claimed.
6. Export and confirm that the message accurately describes an app-private JSON file, not a Downloads/share action. Developer tooling is needed to inspect that private file; automated tests verify exact-owner content. Water must not appear as private account data.
7. Test all five destinations and Back. Return to an existing Workout Saved tab. Check a small screen, landscape, keyboard, 200% fonts, reduced motion and TalkBack.

## Modified files

Full milestone inventory (implementation, regression tests and documentation; no generated files):

- `README.md`
- `docs/ui-ux/README.md`
- `docs/ui-ux/profile-settings-redesign.md`
- `docs/ui-ux/profile-settings-repairs.md`
- `docs/ui-ux/screen-inventory.md`
- `docs/ui-ux/screenshot-checklist.md`
- `lib/features/auth/data/firebase_auth_repo.dart`
- `lib/features/auth/data/user_repository.dart`
- `lib/features/auth/domain/entities/app_user.dart`
- `lib/fitness/models/profile_overview_data.dart`
- `lib/fitness/pages/about_page.dart`
- `lib/fitness/pages/account_security_page.dart`
- `lib/fitness/pages/data_privacy_page.dart`
- `lib/fitness/pages/home_page.dart`
- `lib/fitness/pages/meal_planner_page.dart`
- `lib/fitness/pages/profile_page.dart`
- `lib/fitness/pages/progress_page.dart`
- `lib/fitness/pages/settings_page.dart`
- `lib/fitness/pages/workout_page.dart`
- `lib/fitness/repositories/progress_repository.dart`
- `lib/fitness/repositories/workout_repository.dart`
- `lib/fitness/services/local_storage_service.dart`
- `lib/fitness/services/notification_service.dart`
- `lib/fitness/services/profile_export_service.dart`
- `lib/fitness/widgets/feature_navigation.dart`
- `lib/fitness/widgets/profile_components.dart`
- `lib/fitness/widgets/profile_edit_sheet.dart`
- `test/profile/notification_service_test.dart`
- `test/profile/profile_pages_test.dart`
- `test/profile/profile_repository_test.dart`
- `test/profile/profile_storage_failure_test.dart`
- `test/profile/registration_name_test.dart`
- `test/widget_test.dart`
