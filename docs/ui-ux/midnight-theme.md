# Midnight Navy + Electric Blue — unified identity

Status: final palette and implemented UI approved by the owner after Android phone review. Commit and push to the existing redesign branch are authorized; merging and force-pushing are not. See the [current milestone review](approved-midnight-milestone.md) for final validation.

## Scope

Welcome/Intro, Login, Registration, password reset, Home Dashboard, Workout Plan, and Saved Workouts now share one Material 3 theme. Home's compact layout, two-column activity summary, bottom shortcuts, and coach panel are preserved. Workout preferences, exercise rows, Plan/Saved tabs, filters, save actions, and history structure are preserved.

Authentication is quieter: a small text wordmark, one heading, readable forms, and consistent actions. The previous welcome artwork, branded arrow tile, large promotional headings, and desktop illustration panel are removed. Existing authentication callbacks, controllers, validation, session restoration, and navigation are retained.

## Approved palette

| Token | Value | Use |
| --- | --- | --- |
| Background | `#101827` | Reviewed route canvas |
| Surface | `#1C2940` | Inputs, metric summary, saved-session surfaces |
| Primary | `#315CF5` | Primary actions and selected chip fills |
| Secondary | `#AFC4FF` | Links, focused borders, active tabs, loading indicators |
| Primary text | `#F2F5FA` | Headings, values, active and primary-button labels |
| Secondary text | `#B2BED0` | Supporting copy and inactive labels |
| Outline | `#8396B4` | Readable control boundaries |
| Selected surface | `#253C6C` | Navigation indicator and supporting panel |
| Disabled surface / text | `#26354C` / `#A8B6CC` | Readable unavailable controls |

All brand and surface roles use navy/blue/neutral shades; there is no green, lime, or additional lavender accent in the reviewed presentation. Warm error colors (`#FFB4AB` and `#FFDAD6` on `#4B2029`) are reserved for validation/destructive feedback, not used as brand accents.

The reviewed screens use this dark identity under both light and dark **system** settings. The lightTheme/darkTheme compatibility getters both resolve to Midnight; this milestone does not add a separate light palette or preference storage.

## Central components and tokens

- `lib/fitness/theme/design_tokens.dart`: colors, typography sizes, spacing, 12px control/panel radii, and content/form widths.
- `AppTheme.midnightTheme`: typography, explicit ColorScheme roles, buttons, fields, chips, cards, tabs, navigation, drawers, dialogs, progress, snackbars, and selection feedback.
- `AppThemeScope`: reviewed-route theme and Android system-bar styling.
- The existing `PerformanceScope` and `StudioSpace` names are compatibility wrappers/aliases, not a second theme system.

Typography remains Material/system based: 32px main headings, 24px sections/metrics, 20px titles, 16px body, 14px supporting text, and 12px labels. Content respects system text scaling; the wordmark is a fixed brand lockup. Spacing uses 4/8/16/20/24/32px; existing Home and Workout content stays constrained to 720px, forms to 440px. Primary actions retain a 52px minimum height; controls use padded 48px touch targets.

## Accessibility decisions and evidence

Electric blue is not used as small text on the navy surface: that pairing has only about 2.76:1 contrast. The supplied secondary blue is used for links/tabs/statuses instead.

Measured sRGB contrast examples:

- Primary text on primary action fill: **4.83:1**.
- Secondary blue on the surface: **8.44:1**.
- Secondary text on the surface: **7.75:1**.
- Field outline on the surface: **4.85:1**.
- Disabled text on disabled fill: **6.03:1**.

Duration/filter chips use explicit stateful background, text, and outline colors. Importantly, RawChip resolves a stateful **text color**, not a whole stateful TextStyle; the shared theme accounts for that so selected labels do not inherit an unreadable unselected color. Selected duration remains distinguishable while disabled. Disabled save buttons retain readable labels and remain non-interactive. Active navigation uses light labels on a blue indicator; errors and loading states use their own semantic roles.

These are automated contrast and interaction checks, not an accessibility certification or usability study. TalkBack, actual device rendering, focus visibility, and physical touch behavior still need review.

## Untouched screens and regression boundary

The root MaterialApp and `AppTheme.legacyTheme` are deliberately unchanged. Nutrition, AI Coach, Progress, Profile, and Settings are still pushed as existing routes outside the reviewed scope. They retain their prior hardcoded palette and inherited legacy theme. A visible style difference when entering those pages is an expected remaining migration boundary, not an expansion of this redesign.

Real Home-route tests exercise Workouts, Nutrition, and Progress: Workouts receives Midnight; Nutrition and Progress keep the legacy surface. A separate route/back test verifies scope isolation, and a dialog test verifies that reviewed dialogs capture Midnight. Existing untargeted screen sources and legacy theme values are checked against the pre-milestone state. No new inherited-theme regression was found in these checks; a complete physical-device visual audit remains pending.

## Functionality preservation

No Gemini request logic, Firebase behavior, repository operations, storage fields, records, configuration, or dependencies changed in this milestone. Earlier uncommitted Workout Planner repairs and login work remain present. Business/config files are checked by hash against the pre-theme snapshot; Home/Workout/Login state/action sections are also compared separately from their presentation.

## Android review

Install the debug APK over the existing debug app without clearing its data. Check:

1. Welcome, Sign In, Sign Up, and reset, including loading, inline errors, password visibility, and keyboard scrolling.
2. Home's two-column metrics, Ask Allen panel, active bottom item, drawer, and normal Back behavior.
3. Workout duration selected/unselected/disabled states; generated-plan Save/Completed states; Saved filters, expanded details, errors, and delete confirmation.
4. Both system brightness settings: reviewed screens should remain Midnight. Test enlarged text and TalkBack.
5. Enter and return from Nutrition, AI Coach, Progress, Profile, and Settings. Their old styling should remain; record any unexpected unreadable controls for their later milestones.

The owner has approved the latest visual UI on Android. Live-service and complete workout/restart verification remain manual; current screenshot files have not yet been supplied.

## Files changed for this theme milestone

Presentation/theme:
- `lib/fitness/theme/design_tokens.dart` (new)
- `lib/fitness/theme/app_theme.dart`
- `lib/features/auth/presentation/theme/performance_theme.dart`
- `lib/features/auth/presentation/components/studio_components.dart`
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/intro/intro_page.dart`
- `lib/fitness/pages/home_page.dart`
- `lib/fitness/pages/workout_page.dart`
- `lib/fitness/widgets/allen_components.dart`

Registration and reset receive the shared styling without changes to their source/logic. Tests: `test/theme/midnight_theme_test.dart` (new), `test/widget_test.dart` (fixed-dark expectation and actual route-boundary checks). Documentation: this specification, design-system/history notices, UI/UX index, screenshot checklist, and the main README palette description.

## Validation

Final command results are recorded after completion. The full local suite includes earlier uncommitted workout/login work; no tests contact live Firebase/Gemini or modify real device records.

### Executed results

- `dart format --output=none --set-exit-if-changed`: **passed**, 11 Dart files, zero changes required.
- `flutter test`: **94 passed**, including 10 new theme/accessibility tests and all existing local authentication, dashboard, workout, and persistence regressions.
- Scoped `flutter analyze`: **passed, no issues** in the changed theme/presentation/test scope.
- Full `flutter analyze`: **14 pre-existing diagnostics** in untouched nutrition/profile/progress/settings source (5 warnings, 9 infos); full-project exit remains nonzero. No newly introduced diagnostics remain.
- `flutter build apk --debug --no-pub`: **passed**. Review artifact: `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed.
- Protected-file hash comparison: no changes to API, repositories, persistence, Firebase/Cubit/session behavior, app startup, dependency files, or the unreviewed feature sources during this theme milestone. Home/Workout/Login state/action prefixes and the legacy theme were also unchanged.

These are historical results from the theme implementation stage. The owner has since approved the palette and UI on Android and authorized this branch milestone. See the [milestone review](approved-midnight-milestone.md) for the current checks. No merge is authorized.

## Staged Nutrition extension — historical Planner phase

Nutrition Stage 1 now applies the same AppThemeScope to its app bar/tabs and Planner, including the review-and-log sheet. Tracker and Water content explicitly retains the legacy theme until the next feature stage. This is local work awaiting owner review, not part of the earlier approved milestone. No theme tokens or other feature-screen sources changed. See [Nutrition Stage 1](nutrition-stage1.md).

## Circular Tracker / Water extension — owner-approved

The later owner-requested [Nutrition and Water stage](nutrition-water-trackers.md) replaces the legacy Tracker/Water content described above. All three Nutrition tabs now share Midnight. Rings, form controls, summaries, feedback and loading states reuse existing tokens; no centralized palette changes were needed. Planner presentation and other routes are unchanged in this stage.

The owner has since approved the combined Nutrition feature and authorized publication on the existing redesign branch. See the [Nutrition milestone](approved-nutrition-milestone.md); the earlier staged scope/results above are retained as design history.
