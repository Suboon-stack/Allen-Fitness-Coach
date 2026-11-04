> Historical Planner-stage scope and validation. The subsequent [Nutrition/Water circular tracker stage](nutrition-water-trackers.md) replaces the neighboring legacy tabs while preserving the Planner implementation. The owner has since approved the combined Nutrition milestone and authorized branch publication; see the [current approval/validation record](approved-nutrition-milestone.md).

# Nutrition Stage 1 — Meal Planner

Historical scope: the Planner implementation preceded the circular Tracker/Water stage. Both are now included in the owner-approved Nutrition milestone. Stage-specific decisions/results below describe the earlier work; current publication status is in the linked milestone record.

## Design decisions

The old Planner used multiple chip clusters, a large slider container, decorative meal cards and no log action. It displayed canned meals on provider failure and could show a successful empty result. The new flow follows the existing Midnight Material 3 design system with one heading, compact controls, plain exercise-like meal rows separated by dividers, and clear primary actions.

- Keep Tracker / Planner / Water tab order and existing Home/back navigation. Nutrition's app bar/tabs and Planner use AppThemeScope; the deferred Tracker and Water content explicitly retains its earlier legacy theme. This temporary visual boundary is intentional and documented, not a claim of a finished Nutrition redesign.
- Goal and diet use labeled dropdowns; the same calorie range/steps use a labeled selector rather than a large slider card. Two columns only where width and text scale permit. Target remains a planning preference, not personalized advice.
- A primary Generate meal plan action shows a live loading indicator. Preferences and logging are disabled during requests; repeat callbacks are also guarded. Clear error/retry replaces fallback foods. Last valid suggestions remain after unsuccessful regeneration.
- After generation, preferences collapse into a disclosure. The displayed goal/diet/requested calories are a captured snapshot, not relabeled by subsequent preference edits. Suggested calorie totals are summed only from actual supplied suggestions and labeled separately from recorded intake.
- One row per meal: meal slot, food name, supplied calorie/protein values, supplied carbs/fat when present, and Review & log meal. No feature icons, gradients, oversized cards, or fabricated missing macros.
- Review uses a keyboard-safe scrollable sheet constrained to the existing form width. The user can correct all values and must explicitly choose Log meal for today. Missing macros remain blank; zero is accepted only when supplied/confirmed, never used as a missing-value default. Cancel writes nothing.
- Logged suggestions show Logged today and disable repeated logging. Stable UUIDs and confirmed write handling protect retries. Generating suggestions alone does not change the nutrition summary.

Colors, typography, spacing, shape and interaction states come from existing tokens/theme. No new design system or dependency is introduced. No new research, accessibility certification, measured outcome, screenshot, or live-service success is claimed.

## Android review checklist

1. Install the current debug APK over the existing app without clearing data. Sign in, open Nutrition, and select **Planner**. Tracker remains the existing initial tab.
2. Choose goal, diet and calorie preference; generate. Rapid taps should leave one pending request. Inspect supplied meal values and readability; a provider failure must show an error/retry, not canned food.
3. Generate a second plan with the network unavailable. The previous valid suggestions should remain, with an explicit failure. Restore connectivity and retry.
4. Open Review & log meal. Correct the name/portion values; blank, invalid, negative or nonfinite macros must not save. Cancel first to confirm no entry was created.
5. Review again and confirm Log meal for today only for food you ate. Rapid taps should produce one record. Confirm Logged today, switch to Tracker, and check the name, calories and macro totals. Its full redesign is deferred.
6. Switch tabs and return: the current suggestion plan should remain in memory. Editing preferences must not change the snapshot describing an already-generated plan.
7. Close/reopen the application: the logged meal should persist; an unsaved suggestion plan is not guaranteed to persist. Sign in to a different account and verify meals with another stored userId do not appear. Do not claim water/profile/global account isolation.
8. Check small portrait/landscape, 200% text, open keyboard, Android safe areas, TalkBack, and Back/Cancel while a save is pending. Both system brightness modes should keep the Planner Midnight.
9. Confirm Home, Workouts, Food Scanner, AI Coach, Progress, Profile and Settings still navigate as before. No source redesign of those screens is included.

## Screenshot checklist

Capture genuine Android renders, with device/build, system brightness, and font scale recorded. Current captures are pending; legacy screenshots remain historical references.

- `screenshots/nutrition-planner-midnight.png`: initial compact controls.
- `screenshots/nutrition-suggestions-midnight.png`: provider-supplied results, no personal data.
- `screenshots/nutrition-review-midnight.png`: review sheet/validation/keyboard.
- `screenshots/nutrition-error-midnight.png`: safe generation failure with last valid result retained.
- `screenshots/nutrition-logged-midnight.png`: logged state and corresponding actual Tracker entry.

Never substitute fixtures/mockups for a live Gemini result or fabricate a before/after comparison. The new tests use fixtures only as test inputs.

## Validation

Tests use mocked HTTP, isolated preferences, and a fake authentication repository, never real user records or live Firebase/Gemini.

- `dart format`: passed across all 14 changed/new Dart files.
- Scoped `flutter analyze`: passed, no issues in changed Dart files or new Nutrition tests.
- Full `flutter analyze`: exits 1 with **12 existing diagnostics** (5 warnings, 7 infos), all in unchanged Profile, Progress, Settings, and ProgressRepository files. The two previous Nutrition diagnostics were resolved. Full-project analysis is not claimed to pass.
- Full `flutter test`: **152 tests passed**, including **44 new Nutrition tests** and all 108 earlier regressions. Coverage includes malformed/failed/blocked/truncated AI responses, generation and save guards, retry state, session/disposal handling, preference snapshot retention, unknown macros, UUID reuse, owner-filtered reads, 55-record daily totals, native write acknowledgement/cache reload, and responsive keyboard layouts.
- Water compatibility test: existing sequential writes reload to the same 350 ml total through both ProgressRepository and LocalStorageService, the source Home uses. It also records current cross-account sharing as an unresolved limitation; duplicate-safe/concurrent water writes are not claimed.
- Android debug build: passed; review artifact `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed. Pre-edit source/test hashes confirm no existing source changes outside the explicit Nutrition/dependency/test scope.

Real Gemini/Firebase requests, actual process-restart persistence, full TalkBack/device accessibility, and the user's visual review remain pending. No fixture output is used in production. No commit or push was made.


## Modified files

Presentation:
- `lib/fitness/pages/meal_planner_page.dart` — shared shell, new Planner integration, necessary refresh/error/reflow corrections; legacy Tracker/Water retained.
- `lib/fitness/widgets/nutrition_planner_tab.dart` — new Planner, suggestion rows, review/log form, feedback.

Targeted functionality:
- `lib/fitness/services/meal_plan_parser.dart` — new validated suggestion parser and typed meal errors.
- `lib/fitness/services/ai_service.dart` — explicit meal failures and timeout; shared strict response handling.
- `lib/fitness/repositories/meal_repository.dart` — owner-filtered/unbounded date reads, stable IDs, serialized mutations, surfaced read errors.
- `lib/fitness/services/local_storage_service.dart` — meal-only acknowledgement/cache reload handling.

Tests:
- `test/nutrition/meal_ai_service_test.dart` (new).
- `test/nutrition/meal_plan_parser_test.dart` (new).
- `test/nutrition/meal_repository_test.dart` (new).
- `test/nutrition/meal_storage_failure_test.dart` (new).
- `test/nutrition/nutrition_planner_test.dart` (new).
- `test/nutrition/water_compatibility_test.dart` (new).
- `test/widget_test.dart` — Nutrition shell route-theme expectation.
- `test/workout/workout_ai_service_test.dart` — retains quote fallback assertion; removes obsolete promise of meal fallback.

Documentation:
- `README.md` — Nutrition stage/progress and remaining limitations.
- `docs/ui-ux/README.md` — Nutrition documentation links.
- `docs/ui-ux/midnight-theme.md` — staged Nutrition theme boundary.
- `docs/ui-ux/screenshot-checklist.md` — new pending capture list.
- `docs/ui-ux/nutrition-audit.md` (new).
- `docs/ui-ux/nutrition-repairs.md` (new).
- `docs/ui-ux/nutrition-stage1.md` (new).
