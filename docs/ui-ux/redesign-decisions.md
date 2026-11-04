> Historical Stage 1 record. Later approved changes supersede the statuses and deferred fixes below; see the [current milestone](approved-midnight-milestone.md) and [Midnight design system](midnight-theme.md).

# Redesign decisions — Stage 1

## Scope and evidence

The owner approved a forest/mint Material 3 design system and Home redesign, then explicitly limited implementation to this stage pending visual review. Decisions below reflect source inspection and that brief. No interviews, personas, usability studies, or measured outcomes are claimed.

## Original problems and responses

| Source observation | Implemented response | Reason |
| --- | --- | --- |
| Fitness pages use hardcoded dark Pallete values; auth uses theme values | Central semantic light/dark themes; Home adopts them locally | Establish consistency while preserving unreviewed screens |
| Home repeats styled containers and gesture controls | Shared bordered Material cards, button, section title, spacing | Consistent states, focus, and maintainability |
| Five colorful feature rows compete with quote and metrics | One mint coach panel, restrained feature cards, motivation last | Make the coach and practical actions easier to scan |
| Fixed horizontal stats and non-scrolling drawer | Responsive wrapping and scrolling drawer | Accommodate narrow windows and larger text |
| Failure substitutes a motivational quote without explaining activity failure | Explicit activity error and retry; tools remain available | Provide honest feedback and recovery |
| Home test is unrelated counter starter code | Dashboard tests with injected existing service types | Cover actual states without Firebase/network calls |

Home preserves workout, meals, food scanner, progress, AI chat, profile, settings, About, and logout access. Existing feature pages remain unchanged. Standard Material routes return to Home, which refreshes its existing data. No bottom navigation was added because that would introduce navigation scope beyond this review.

## Deferred bugs — separate from UI changes

### Dashboard statistics source mismatch (not fixed)

Root cause: Home reads StorageService keys (`weight_logs`, `workout_count`, `streak`), while fitness repositories use LocalStorageService keys (`weights`, `workouts`) and derive counts/streaks. Refreshing cannot reconcile these separate records. Settings' clear-weight action also targets StorageService. Home keeps the existing source in this stage; zero values can disagree with Progress.

Proposed separate fix: make Home read the existing workout/progress repositories, define handling of legacy records explicitly, and verify values after saving/completing/logging. Preserve repository signatures and storage formats. Explain the specific patch before implementation; do not silently migrate records.

### Workout completion ID (not fixed)

Root cause: WorkoutPage._markAsDone saves a workout, then passes `_exercises.first.name` to `markWorkoutComplete`, which searches the saved workout UUID. The new record is therefore not identified. The save action currently discards createWorkout's returned ID.

Proposed separate fix: retain the returned workout ID in the completion flow and pass it to the existing repository method. Verify save-only and complete actions separately. No changes to WorkoutPage or repositories are included in Stage 1.

## Validation and review

- Formatting: successful with the working standalone Dart SDK.
- Standalone Dart analysis of all changed Dart files: passed, no issues. Full-project standalone analysis: 16 existing diagnostics (5 warnings, 11 infos), all in unchanged files; no errors. These remain outside Stage 1.
- `flutter analyze` and `flutter test`: attempted; both fail at SDK startup with “Wrong full snapshot version”. Tests have not passed or executed.
- Widget coverage added: pending loading, resolved saved count, empty weight, retry recovery, narrow layouts at 200% text in both themes, and drawer destinations.
- Manual review needed: actual Home appearance in both device themes, phone/tablet/desktop widths, screen-reader and keyboard navigation, route return behavior, pull to refresh, and live Firebase/Gemini/device integration.

Stage 1 stops here for owner review. Further screen redesigns and both bug fixes are deferred.
