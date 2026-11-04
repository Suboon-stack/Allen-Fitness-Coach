# Workout Planner — approved UI implementation

Scope: Workout Planner presentation, pure workout parsing, targeted workout service/repository fixes, workout-only persistence failure handling, and tests. The UI is owner-approved after Android review and included in the authorized Midnight milestone on `redesign/performance-studio-auth`. Full functionality verification is tracked separately. No screen beyond Workout Planner was redesigned.

## Audit observations

The original page mixed three groups of pill controls, generation feedback, oversized exercise cards, and save/completion buttons in one long scroll. Saved history showed only a few exercise names, repeated large status cards, and performed writes without local loading/error/refresh feedback. Its FutureBuilder recreated history requests on rebuilds and treated failed reads like an empty history. The default legacy palette was inconsistent with the approved Home theme.

Source inspection confirmed an exercise name was passed to UUID-based completion; repeated saving could create records; parsing indexed an assumed `sets x reps` shape and invented 3/10 defaults; Gemini errors silently returned predefined workouts. Preferences could be changed after generation and then incorrectly relabel the saved plan. Further persistence inspection confirmed ignored native write acknowledgements and optimistic SharedPreferences cache values could falsely resemble durable records.

## Design decisions

- Keep the existing two-tab hierarchy, renamed **Plan / Saved**. Android Back returns to the existing caller; no new navigation shell or workout routes are introduced.
- Follow Home's centralized Material 3 styling, constrained 720px content width, 20px page padding, and restrained typography. The initial forest/mint palette was superseded by the approved [Midnight identity](midnight-theme.md), which stays dark under both system brightness settings.
- Replace the focus/level chip collections with labeled dropdowns. Keep the four existing durations as wrapping choices with accessible touch targets. No new fitness preferences or equipment assumptions are added.
- Before generation, show a focused planning form. After generation, prioritize the plan title, actual preference snapshot, exercise count, save status, and readable exercise rows. Preferences move into a disclosure so they no longer occupy the whole page above every plan.
- Exercise rows share dividers instead of one large card each. Repetitions and muscle labels come from the response. Optional supplied rest/instructions are displayed; no rest values, exercise defaults, or progress figures are invented.
- Keep Save / Save & complete accessible in a fixed action area. After saving, completion targets the saved ID; completed plans expose a completed state instead of another active completion action. Actions wrap vertically on narrow/enlarged-text layouts.
- Saved workouts have All / Ready / Completed filters, compact expandable summaries, full exercise details, completion feedback, confirmation before deletion, and pull-to-refresh. Show the existing latest-50 history limit explicitly when reached.
- Prevent duplicate generation and overlapping writes. Allow leaving during generation safely, but wait for persistence mutations before returning so Home's existing return-refresh observes completed data.

These decisions follow the owner brief and code audit. No user research, usability study, or measured improvement is claimed. Android UI approval is based on the owner’s report; it does not establish full functionality verification.

## Storage and compatibility

No storage keys, field types, repository signatures, Firebase settings, or dependencies changed. New generated plans retain their exact source in the **existing** optional Workout.notes string so supplied rest/instructions survive saving; older records and personal notes remain readable. The draft UUID is generated before saving and honored by createWorkout for retry idempotency. Existing callers supplying an empty ID still receive a generated UUID.

The existing date field becomes the actual completion/activity date on the first transition to completed, while createdAt remains the saved creation timestamp. Repeated completion does not change that date. Previously completed records are not rewritten or migrated. This lets the existing Home/Progress calculations use the completion day correctly without modifying those screens.

The Exercise model supports integer repetitions, not timed holds or rep ranges. The workout prompt requests repetition-based exercises; unsupported prescriptions are rejected with retry feedback instead of converted to fabricated reps. Rest/instructions are preserved only when actually supplied.

See [separate functionality repair notes](workout-repairs.md) for root causes and coverage.

## Android review steps

1. Install the debug APK over your existing debug app; keep its data. Sign in and open Workouts from Home.
2. Change focus, level, and duration. Generate a workout. Rapid taps should create one in-flight request, and controls should remain stable while loading.
3. Inspect exercise names, sets/reps, and any supplied instructions. Save once, then tap completion. Confirm one saved row and a clear completed status.
4. Try Save & complete on a fresh plan. Check Saved filters and expand a session to see all exercise details. Test canceling a delete confirmation before testing deletion on a disposable session.
5. Return Home and open Progress. Completed count/streak should match persisted records; saving an incomplete plan should not count as completed.
6. Close/reopen the app and confirm saved exercises, instructions, and completion remain. Actual process-restart verification is a manual device check; automated tests reload the persisted test-store representation.
7. With no network or unavailable Gemini quota, verify an explicit error/retry rather than a canned workout. Failed regeneration must leave the previous valid plan intact.
8. Review narrow/landscape layouts, both system themes, 200% text, TalkBack labels, and all back actions. Unsaved drafts are in-memory and are not promised to survive leaving or restarting.

## Remaining boundaries

Live Gemini availability/output quality, physical-device storage failures, real restart behavior, and TalkBack need manual review. Existing local account data isolation remains a separate problem. Meal/chat/quote fallback behavior is unchanged. History remains limited to the latest 50 sessions by the existing repository default. The owner has authorized committing and pushing this approved UI/workout milestone without merging into main.

## Validation

Actual final command results will be appended after checks finish. Tests use mock HTTP responses and isolated preference stores; production does not contain fixture plans or a workout fallback.

### Executed results

- Formatting check: **passed**, 11 changed/new Dart files, zero formatting changes remaining.
- `flutter test`: **84 passed** in the current local working tree, including 50 new workout tests and the existing 34 Home/authentication tests. Test HTTP responses and native preference handlers are mocked; no live Gemini request or real account operation was performed.
- Scoped `flutter analyze`: **passed, no issues** across WorkoutPage, workout repository, AI/persistence services, parser, exercise/feedback widgets, and workout tests.
- Full `flutter analyze`: **14 pre-existing diagnostics** (5 warnings, 9 infos) in unchanged nutrition/profile/progress/settings files. No workout diagnostics remain; the full-project command exits nonzero because of those existing diagnostics.
- `git diff --check`: passed.
- The previously uncommitted login/test/design-document files were compared with the pre-workout backup and remain byte-identical. Home, Progress, Firebase configuration, credentials, and dependency files were not edited.

### Changed/new files for this feature

Presentation:
- `lib/fitness/pages/workout_page.dart`
- `lib/fitness/widgets/workout_widgets.dart` (new)

Targeted functionality:
- `lib/fitness/services/workout_plan_parser.dart` (new)
- `lib/fitness/services/ai_service.dart`
- `lib/fitness/repositories/workout_repository.dart`
- `lib/fitness/services/local_storage_service.dart` (workout read/write paths only)

Tests (all new):
- `test/workout/workout_plan_parser_test.dart`
- `test/workout/workout_ai_service_test.dart`
- `test/workout/workout_repository_test.dart`
- `test/workout/workout_page_test.dart`
- `test/workout/workout_storage_failure_test.dart`

Documentation:
- `docs/ui-ux/workout-planner.md` (new)
- `docs/ui-ux/workout-repairs.md` (new)
- `docs/ui-ux/screenshot-checklist.md`
- `docs/ui-ux/README.md`

Android debug build: **passed**. Review artifact: `build/app/outputs/flutter-apk/app-debug.apk`. It has not been committed or uploaded. No current after screenshots have been added. The owner has since reported Android UI approval; complete live-service and persistence checks remain pending.
