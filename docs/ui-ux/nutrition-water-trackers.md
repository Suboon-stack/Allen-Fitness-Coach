# Nutrition and Water — circular trackers

Status: the owner approved the Nutrition feature and authorized committing/pushing it to `redesign/performance-studio-auth`. This milestone includes the preserved Planner work and circular trackers, based on approved commit `c50456a`. No merge or force-push is authorized. See the [publication validation](approved-nutrition-milestone.md).

## Evidence and scope

The owner requested matching circular-progress trackers, an apple/drop visual, actual recorded values, conditional goals, modal meal logging, and reliable water additions. Decisions below use that brief and code inspection. The owner’s approval is recorded without inventing research participants, usability studies, measured outcomes, detailed Android test results, or new screenshot captures.

This stage replaces Tracker and Water inside the existing Nutrition route. Tracker / Planner / Water order, Home entry, and Back navigation remain. The Planner widget, Gemini requests/parser, authentication, Home, Food Scanner, AI Coach, Progress, Profile, and Settings source files are unchanged during this stage. The host page connects Planner saves to the new Tracker refresh; a Planner preference never becomes a saved calorie goal.

## Design and component specifications

Both trackers use the existing `AppThemeScope`, Midnight ColorScheme and design tokens. No new palette, font, dependency, image download, gradient, shadow, or oversized card is introduced.

- **TrackerProgress:** a shared 224px ring, reduced to 168px in short landscape layouts and constrained by available width. Eight-pixel electric-blue progress stroke, subtle navy track, soft-blue center icon. Nutrition uses an original small apple outline drawn in Flutter; Water uses an outlined drop.
- Recorded values use the existing 32px heading style. At enlarged text sizes or for long numbers, values move below the circle to preserve text scaling rather than squeeze inside it. Units and goal labels wrap naturally.
- A known positive finite goal enables percentage text and the progress arc. The arc stops at 100%; the actual percentage can exceed 100%. Missing/invalid calorie goals show the recorded number and an explicit no-goal message, with no invented percentage. Loading is a separate labeled indicator; it is not represented as a zero-value ring.
- Progress changes interpolate for 250 ms using ease-out cubic. Reduced-motion or accessible-navigation settings remove interpolation. An accessible ring label includes the actual amount, unit and goal information; decorative icon/arc semantics are excluded to avoid duplicate announcements.
- Protein, Carbohydrates, and Fat share one compact navy summary strip. Values come from the same recorded-meal snapshot as the calorie ring and meal list. Optional saved macro goals show their own percentages; there are no 150/250/65 g defaults. The strip reflows to one column for large text.
- Today's meals are divider-separated text rows: category, name, calories and supplied macros. Empty/error/loading states are explicit. There are no repeated food icons or large meal cards.
- Add Meal opens a scrollable, keyboard-safe bottom sheet. It retains category, name, calories, protein, carbohydrates and fat fields. Required values are validated; calories are whole nonnegative numbers and macros finite nonnegative grams. Explicit zero is allowed; blank/malformed input is never replaced with zero. Fields remain visible through loading/errors.
- Water uses wrapping Material quick-add buttons for +100/+250/+500 ml. All are disabled while a write is pending, and become available for an intentional later addition after confirmation. Success and error feedback are explicit. The existing 2,000 ml target is labeled **App default goal**, not a configured/personalized recommendation.

## Data and targeted fixes

| Confirmed cause | Repair |
| --- | --- |
| Tracker treats Planner's calorie selector and hardcoded macro values as daily goals | Read existing profile target fields only when stored `id` matches the signed-in account; accept positive finite values only. Do not write goals or substitute defaults. A profile read failure does not hide valid meal totals. |
| Separate totals/list requests and FutureBuilder rebuilds can disagree or repeat reads | Load one owned daily-meal snapshot and derive both totals and list from it; cache until refresh/save/day change. Guard late requests by request ID and account. |
| Blank or missing stored nutrition becomes zero | Validate stored nutrition; surface a safe read error while preserving raw data. Invalid new writes are also rejected. No partial/fabricated totals are displayed. |
| Manual form has no validation and overlapping writes are possible | Validated sheet, single-flight save, stable UUID across retries, preserved draft values. If an uncertain first write reached disk, a retried edited draft updates that same UUID rather than duplicating or silently retaining older values. |
| Water read-modify-write calls can race | Serialize water additions within the existing LocalStorageService; capture the requested date before queuing. Both intentional additions survive. |
| Native water write acknowledgement is ignored and preference cache changes before disk confirmation | Check native result; reconcile uncertain writes by reload. If the expected total is confirmed, report success. Otherwise show an error and require refresh before adding again. Reads, including Home reads, await an in-flight write and verify uncertain cache state. |
| A mounted tracker can retain yesterday's values | Refresh on app resume, local midnight, and tab checks; discard stale async day results. |

The shared dependency was explained before editing: only water methods/state in LocalStorageService and nutrition validation in MealRepository are extended for these trackers. ProgressRepository's existing water contract and Home's caller stay intact. Meal and water storage keys/field types are unchanged; no migration, reassignment, deletion, or new goal storage occurs.

## Known storage limits and approval boundary

- Water is still a single integer under `water_YYYY-MM-DD`. There are no individual entries/IDs/timestamps to show, undo, or delete. The UI states this limitation rather than fabricating history.
- These date-only totals are shared across accounts on the device. Isolating water requires an approved ownership/key design and a decision about unowned legacy totals. Such a change is not implemented; explicit approval is required before changing keys or migrating data.
- Meals retain the prior stage's existing-userId filtering. Unowned legacy meals remain stored, but are not assigned to the current account. Invalid legacy records remain unchanged and produce a clear error instead of guessed nutrition values.
- Profile storage and raw Progress statistics have wider ownership limitations. This stage only uses clearly owned existing profile targets and does not change those features.
- Home currently summarizes water, not meal calories. Automated integration verifies water agreement after returning from Nutrition. No new Home metric is introduced.

## Android testing checklist

1. Install the debug APK over the existing app without clearing its data. Open Nutrition → Tracker. With no valid saved calorie goal, verify the logged total and no percentage. With an existing owned profile goal, verify its value and percentage. A Planner preference must not change the configured target.
2. Check calorie and macro totals against today's meal records. Pull to refresh. Confirm the empty state on an account/day without meals and retry behavior on a read error.
3. Open Add Meal. Submit blank/invalid fields; then enter real portion values. Check keyboard scrolling, category selection, Cancel, loading, draft retention after failure, and exactly one new row after rapid save taps.
4. Switch to Water. Verify the clearly labeled 2,000 ml app default and actual saved amount. Add 100, 250 and 500 ml intentionally; repeated taps during one save must not multiply the amount. A later separate addition should work.
5. Return Home and confirm Water today matches. Reopen Nutrition and restart the application to verify real device persistence. Tests simulate native storage reload, but do not establish an actual Android process-restart result.
6. Review both trackers in small portrait/landscape, 200% text, both system brightness settings, gesture/navigation safe areas, TalkBack, and reduced-motion mode. Test app resume and crossing midnight when practical.
7. Confirm the existing Planner layout/generation/review flow still works. Other feature screens should remain unchanged.

## Screenshot checklist

All captures below are pending. Use genuine Android renders, record build/device/font scale/system brightness, and remove personal details.

- `screenshots/nutrition-tracker-circular.png`: owned recorded totals and compact macros.
- `screenshots/nutrition-tracker-no-goal.png`: actual totals without a configured target/percentage.
- `screenshots/nutrition-add-meal.png`: sheet, keyboard and inline validation.
- `screenshots/water-tracker-circular.png`: recorded total, labeled app default, quick additions.
- `screenshots/tracker-large-text.png`: small screen/large text reflow.
- `screenshots/tracker-recovery.png`: safe error/retry state.

Historical Tracker/Water captures under `docs/screenshots/` are before references only. Do not recolor them or present test fixtures as evidence of live functionality.

## Validation

Executed results:

- `dart format`: passed across all 21 pending changed/new Dart files, including preserved Planner work. Final formatting verification reports no changes.
- Scoped `flutter analyze`: passed, no issues across all 21 pending Dart files.
- Full `flutter analyze`: exits 1 with **12 existing unrelated diagnostics** (5 warnings, 7 infos), in unchanged Profile, Progress, Settings and ProgressRepository source. No errors or tracker diagnostics remain; full-project analysis is not claimed to pass.
- Full `flutter test`: **185 tests passed** — 33 added in this circular-tracker stage, 44 from the preserved Planner stage, and 108 from the approved milestones. Coverage includes goal-free/invalid/owned goals, exact recorded sums, semantics/reduced motion, form validation/cancel/save/retry, duplicate tap guards, intentional later water additions, native write/reload/acknowledgement failures, concurrent additions, Home water agreement, and 320px/landscape/200%-text/keyboard layouts.
- Android debug APK: built successfully at `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed. A pre-stage backup/hash snapshot confirms Planner widget, Gemini service/parser, Home, other feature sources, authentication and existing unrelated repositories are unchanged during this stage. The prior uncommitted work is preserved.

Automated tests use isolated preferences, fake authentication and mocked native writes; no live Firebase/Gemini call or real user record is used. Those were implementation-stage checks. The owner has since approved the feature and authorized this branch publication. Complete TalkBack, process-restart, lifecycle/midnight and live-service checks remain separately tracked; no new screenshot or detailed device-test result is claimed. Current pre-push results are recorded in the [approved milestone](approved-nutrition-milestone.md).

## Files changed in this stage

Production:
- `lib/fitness/pages/meal_planner_page.dart` — Tracker/Water composition, cached loads, independent state, day/session refresh, modal integration; Planner child preserved.
- `lib/fitness/models/nutrition_tracker_data.dart` (new) — read-only existing-goal projection and recorded-total validation.
- `lib/fitness/widgets/tracker_progress.dart` (new) — shared ring, semantics, reduced-motion behavior and apple outline.
- `lib/fitness/widgets/meal_entry_sheet.dart` (new) — manual meal entry, validation and safe retries.
- `lib/fitness/repositories/meal_repository.dart` — reject missing/invalid stored nutrition and invalid new entries without changing raw data/schema.
- `lib/fitness/services/local_storage_service.dart` — water-only serialization, validation and acknowledgement/reload handling; earlier workout/meal paths preserved.

Tests:
- `test/nutrition/nutrition_tracker_data_test.dart` (new).
- `test/nutrition/tracker_progress_test.dart` (new).
- `test/nutrition/water_storage_test.dart` (new).
- `test/nutrition/nutrition_water_tracker_test.dart` (new).
- `test/nutrition/meal_repository_test.dart` — invalid/missing nutrition coverage.
- `test/nutrition/nutrition_planner_test.dart` — updated assertion for the neighboring Tracker's actual goal-free ring; Planner interaction coverage retained.

Documentation:
- `README.md`.
- `docs/ui-ux/README.md`.
- `docs/ui-ux/midnight-theme.md`.
- `docs/ui-ux/nutrition-audit.md`.
- `docs/ui-ux/nutrition-repairs.md`.
- `docs/ui-ux/nutrition-stage1.md`.
- `docs/ui-ux/screenshot-checklist.md`.
- `docs/ui-ux/nutrition-water-trackers.md` (this file, new).
