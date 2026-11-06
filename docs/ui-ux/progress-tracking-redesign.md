# Progress Tracking — approved for milestone finalization

## Brief, reference and approval

The owner approved the six-stage plan and supplied `Dark Navy Fitness Progress Dashboard.png` as the primary visual reference on 5 November 2026. Follow its Timeline Style: mountain journey banner, interactive blue weight chart, compact key progress area, and dated vertical activity timeline. Reference numbers and achievements are illustrative, not application data. No user research or usability study is claimed.

Work is on `feature/progress-tracking-redesign`, created from clean, synchronized main at `e50d1e5`. The owner separately approved adding account/identity metadata to new weights, ownership enforcement on reads and mutations, retaining legacy records, and deferring water migration. On 6 November 2026 the owner declared the implementation complete and authorized committing/pushing the feature and a normal merge into main, conditional on acceptable validation and review. No force-push, history rewrite, branch deletion or further feature work is authorized. No detailed Android test results were supplied, so none are inferred from this approval.

See [the audit and root causes](progress-tracking-audit.md) for the original UI, fabricated calorie-burn calculation, ineffective period controls, missing weight identities/ownership and other confirmed problems.

## Visual and interaction decisions

- **Your Journey:** an original static CustomPainter mountain/flag illustration in existing blue/navy tokens. Use actual selected-period weight change/check-in count, or actual workout/meal history, with neutral encouragement. Do not assume loss, gain, a target weight or a successful health outcome.
- **Weight Progress:** the existing `fl_chart` dependency renders a straight electric-blue line and restrained fill, visible kg bounds/date labels, points and selected date/value. Use elapsed timestamps rather than equally spaced list indices. Straight segments avoid suggesting unrecorded smoothed measurements. A padded, explicitly labeled vertical range is not a zero-baseline chart. The horizontal range matches the selected period; future records are excluded.
- **Periods:** 7D and 30D include today's local calendar date and the previous 6/29 dates. 3M and 1Y use calendar-month/year lookbacks, clamping month ends/leap days. All end at the current time. Empty periods show a log action; one measurement shows a point and an explanation rather than a fabricated trend.
- **Accessible inspection:** tap points for a tooltip and retained date/value; previous/next buttons and See details provide alternatives to precise gestures. Details list each date/value and open the selected owned record for editing. Selected point styling is distinct. Native Android gestures/TalkBack remain device checks.
- **Key Progress:** workout count covers the selected period; nutrition/calorie and optional protein rings use today's actual logged meals and valid targets from the account's stored profile. Missing data is shown as a dash with an explanation, not an assumed zero. Workouts have no saved session target, so show a count without a percentage/ring. Water is explicitly unavailable as personal data. The fourth protein metric exists only with recorded nutrition and a saved protein target. Four compact metrics fit one row on normal phone widths; small/enlarged-text layouts wrap. Over-target values retain actual totals; ring geometry caps at a full circle and does not imply a health recommendation.
- **Activity Timeline:** actual owned weight logs, currently completed workouts, dated logged meals, and a first-recorded-weight milestone derived from history. No invented streaks, calorie burn or water-entry events. Workout minutes are labeled as planned duration, not measured active time. Scanner meals retain their reviewed AI-estimate label. Display 40 events at a time with Show more; all supported events remain available.
- **Logging/editing:** a keyboard-safe sheet with visible kg/date/optional-notes fields. Require a finite positive weight up to the operational 1,000 kg limit, a non-future measurement date and notes up to 500 characters. Stable UUID/date/creation values survive uncertain-save retries. Inline errors retain entered values. Deletion requires confirmation and targets only the owned selected UUID.
- **Navigation:** preserve Allen's existing four Home/Workouts/Nutrition/Progress destinations, selected Progress state, and existing feature routes. Home returns through the existing route stack; feature shortcuts refresh Progress on return. Do not add the reference's Profile destination or restructure the app shell. The profile remains reachable through existing Home navigation.

Use the centralized Material 3 Midnight palette: `#101827` background, `#1C2940` surfaces, `#315CF5` primary, `#AFC4FF` secondary, `#F2F5FA` text and `#B2BED0` supporting text. Reuse existing 20 px page padding, spacing/typography tokens, 12 px corners, outlined inputs and Material controls. No new package, gradient, shadow system, theme or animation dependency is introduced.

## Data sources and calculations

| Area | Existing data and interpretation |
| --- | --- |
| Weight | `weights` JSON list, read through ProgressRepository with exact `userId` filtering. Chart/history read beyond the old 100-entry cap; Home/Profile use the same owned reader for their latest logged weight. Profile's separate weight field is not fabricated into a dated measurement. |
| Workouts | Read-only projection of existing `workouts` records filtered by exact owner and `completed == true`. Require usable UUID/name/date/planned minutes. No latest-50 history cutoff for this projection. The activity date is the stored completion date maintained by the Workout milestone. Repeated completion sessions are not stored as a separate archive. |
| Nutrition | Existing MealRepository owner-filtered records, beyond its default 50-record display limit. Use actual meal dates/calories/macros; generated suggestions are not intake. Daily totals use the local date. |
| Targets | Existing owned `user_profile` calorie/protein targets, validated by NutritionGoals. No new goals or defaults are saved. A missing/mismatched profile supplies no personal targets. |
| Water | Existing daily totals remain device-wide, not account-owned; no water migration, personal percentage or invented event is added. Nutrition/Home water behavior remains unchanged. |
| Milestones | First recorded weight date among the account's retained usable history, only shown in its actual period. It is not claimed as the person's first-ever measurement. |

Filtering and calculations live in the pure `progress_tracking_data.dart` projection. Unavailable sources are null, while successful empty reads are empty lists. ProgressRepository loads independent sources with per-section failure flags so a failed weight read does not erase real workout/nutrition history. Food intake is never multiplied into calories burned.

## Approved storage repair and compatibility

The key remains `weights`, with the same JSON list representation. New entries add `id`, `userId`, `createdAt` and optional `notes` alongside weight/date. They use the existing WeightEntry model. There is **no bulk rewrite, migration, legacy ownership assignment or deletion**. When adding/editing one owned entry, preserve every legacy/foreign record and unknown field.

Production mutations verify Firebase's current user; the form also checks the verified AuthCubit identity. Recheck ownership when a queued write begins and after reading the current records. Editing/deleting requires an unambiguous matching UUID whose stored owner matches the authenticated user. Reject foreign/unowned/missing/duplicate identifiers and attempted ownership transfers. Edits change only weight/date/notes; ID, owner and exact stored creation metadata are retained.

Serialize weight mutations across repository instances, acknowledge native writes, reload uncertain preference caches, and retain the draft ID on retry. A previous save may have reached disk before acknowledgment failed; retrying creates no duplicate and reconciles any reviewed edits against that same ID.

**Visible compatibility impact:** old unowned weights remain stored but are excluded from personal Progress, Home and Profile weight summaries. Do not infer that they were deleted. The chart empty state and data-information dialog explain this. Owned historical records without an ID can be displayed but cannot be edited/deleted until a separately approved identity repair; this milestone never manufactures their identities on read. The nullable latest-weight contract used by existing Home/Profile is preserved on unreadable storage; Progress's strict history reader shows a proper retry state. The Home regression fixture now uses an owned weight and recognizes Progress's approved Midnight theme.

If an account changes after a native write has already started, that write cannot be rolled back merely by closing a form. It keeps the original owner's ID; stale completion does not update the next account's UI. Logging/editing never assigns a record to the replacement account. Back/disposal/account changes invalidate pending reads and dismiss stale account-owned forms, including an overlaid deletion confirmation.

## Remaining limitations

- Water ownership/history migration remains deferred. No personal water value is shown here.
- No saved workout-session or target-weight goals exist; their percentages are intentionally absent. Protein is conditional, not a fabricated fourth metric.
- Unknown-owner legacy weights are retained, not migrated. They have no personal edit/claim flow in this milestone.
- Other feature paths still have known device-shared storage behavior, including workout counts/history, profile storage and Settings export/clear-data paths. This milestone does not redesign or repair those screens. Progress uses its own owner-filtered workout projection; the shared weight reader is the approved cross-feature dependency.
- Personal records remain local SharedPreferences data, not cloud backups. Cross-device sync is not implemented.
- Native storage durability/restarts, real Firebase session transitions, device chart gestures, accessibility and appearance require the owner's Android review. Automated fakes do not establish real-device verification.
- No genuine Progress screenshots have been supplied. Any temporary fixture renders used during development are not device evidence or portfolio screenshots.

## Validation performed on 5 November 2026

- `dart format`: all 14 changed/new Dart files formatted; final check requires zero additional changes.
- `flutter test --no-pub`: **350 tests passed**, including **45 new Progress tests** (9 date/calculation tests, 13 repository/ownership tests, 6 native-storage failure tests and 17 widget tests). The existing Home navigation regression was updated for the new approved theme and account-owned weight fixture; no existing test was removed.
- `flutter analyze --no-pub`: **7 pre-existing diagnostics** remain in unchanged Profile/Settings code: 4 warnings and 3 infos, no errors and no new Progress diagnostics. The prior milestone had 12 diagnostics; the rewritten Progress code removes 5. Analysis still exits 1 because those existing diagnostics remain.
- `flutter build apk --debug --no-pub`: successful Android debug build, `build/app/outputs/flutter-apk/app-debug.apk`.
- Scope/hash review confirms Home, Profile, Settings, Workouts, Nutrition, Scanner, Chat, AI service and dependency manifests are unchanged. The approved shared dependencies are ProgressRepository's weight reader and LocalStorageService's weight persistence only.
- Changed-file review found no credentials, generated build files or secrets. No staging, commit, push, branch merge or history rewrite was performed.

Coverage includes calendar/leap boundaries, irregular dates, missing/single-point data, actual nutrition totals, real completion projections, legacy/foreign preservation, forged IDs/ownership transfers, signed-out and queued-account changes, editing immutable metadata, duplicate/uncertain saves, storage errors/reloads and persistence across preference-cache/repository reconstruction. Widget coverage includes empty/populated/global/partial errors, retry, chart controls/touch callback, accessible details, saving/editing, account changes during editing/deletion confirmation, stale reads/disposal, duplicate-save blocking, keyboard/system insets and 320×568/390×844/800×400 layouts at 200% text.

Tests use fake authentication, isolated/mocked native preferences and controlled data, not a live Firebase session or real-device durability test. A separate temporary fixture render was used only for development inspection and was not added as screenshot evidence. No Android phone verification is claimed.

## Publication review on 6 November 2026

The owner authorized finalization conditional on acceptable checks. Fresh validation completed: formatting all 14 Dart source/test files made no changes; all **350 tests passed**, including the **45 Progress tests** above; the Android debug APK built successfully. Full analysis reports exactly the same **7 existing diagnostics** (4 warnings, 3 infos in unchanged Profile/Settings files), no errors and no new findings. Its exit code is 1 because of those existing diagnostics.

Review covered all 19 milestone paths and the tracked repository for common secret patterns and the locally configured Gemini credential (compared in memory without exposing it). No credentials, generated files, dependency changes or unrelated feature changes were found. The app source/tests were unchanged during finalization; only documentation was updated. Legacy/foreign preservation and mutation ownership were reconfirmed in code and passing tests. The LocalStorageService water section is byte-for-byte unchanged from main, confirming no water migration was introduced.

Detailed Android device outcomes/screenshots were not supplied with finalization approval. The remaining device/regression checks above and below are not claimed as performed. The authorized Git workflow is a feature commit/push followed by a conflict-free normal merge into main, retaining the feature branch and stopping further development.

## Changed files

| Area | Files |
| --- | --- |
| Progress screen | `lib/fitness/pages/progress_page.dart` |
| Data/calculations | `lib/fitness/models/progress_tracking_data.dart`, `lib/fitness/repositories/progress_repository.dart` |
| Weight persistence | `lib/fitness/services/local_storage_service.dart` (weight section only) |
| Presentation components | `lib/fitness/widgets/progress_journey.dart`, `progress_chart.dart`, `progress_metrics.dart`, `progress_timeline.dart`, `weight_entry_sheet.dart` |
| Tests | `test/progress/progress_data_test.dart`, `progress_repository_test.dart`, `weight_storage_failure_test.dart`, `progress_page_test.dart`; `test/widget_test.dart` |
| Documentation | `README.md`, `docs/ui-ux/README.md`, `docs/ui-ux/progress-tracking-audit.md`, `docs/ui-ux/progress-tracking-redesign.md`, `docs/ui-ux/screenshot-checklist.md` |

19 new/modified files. No new dependencies or automatic migration.

## Android regression checklist

1. Install the debug APK over the current debug app without uninstalling or clearing storage. Sign in and open Progress from Home.
2. Compare the banner, chart, key metrics and vertical timeline to the approved reference. Check Home/Workouts/Nutrition/Progress shortcuts and Android Back.
3. Confirm legacy/unowned weights are absent from personal summaries but not deleted. Log a new dated weight and optional note. Verify it appears in Progress and Home's latest-weight summary after return.
4. Exercise 7D/30D/3M/1Y, empty and single-point states. Tap points and use previous/next/See details; check irregular dates are not equally spaced. No trend should be shown without enough measurements.
5. Edit an owned value/date/note and verify the same record changes rather than a duplicate appearing. Test invalid/blank/non-finite values, duplicate Save taps, Cancel and the delete confirmation.
6. Fully restart the app and confirm the owned measurement persists. Sign out and use a second account: the first account's weights, nutrition and Progress completion events must not appear. Log a second-account weight, switch back and verify separation. Unowned records must never be assigned automatically.
7. Check workout completions and genuine meal logs appear with correct dates. Planned workout minutes must not be called measured duration or calorie burn. Nutrition/protein rings require actual meals and saved owned goals. Water should explain its unavailable personal-data status.
8. Test small Android screens, landscape, 200% text, keyboard and navigation-bar insets, TalkBack, interrupted loads and account changes while an edit/delete sheet is open. Check existing Workout, Nutrition, Scanner and Chat flows still work.

The owner has approved milestone finalization subject to validation. Keep this checklist for device regression coverage; it does not claim every scenario was performed. Stop after the authorized publication/merge and do not begin another feature.
