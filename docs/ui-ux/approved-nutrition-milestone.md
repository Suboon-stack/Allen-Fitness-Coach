# Approved Nutrition milestone

The owner approved the Nutrition feature and authorized committing and pushing it to the existing `redesign/performance-studio-auth` branch on `Suboon-stack/Allen-Fitness-Coach`. No main-branch merge or force-push is authorized. Approval does not imply completion of every manual test listed below.

## Feature behavior

- **Tracker:** today's saved meals drive the calorie ring, compact macro totals and recorded-meal list. Only positive finite saved goals with a matching profile owner enable goal percentages. Planner calorie preferences are separate from configured goals.
- **Meal logging:** Add Meal opens a validated, keyboard-safe sheet. Values survive loading/errors; a stable UUID protects retry from duplication. A confirmed save refreshes the Tracker.
- **Planner:** existing goal/diet/calorie preferences generate Gemini suggestions. Invalid/blocked/failed responses show safe retry feedback instead of canned fallback meals. Suggestions become intake only after the user reviews and explicitly logs a meal; missing macros are not invented.
- **Water:** matching ring with +100/+250/+500 ml additions; the 2,000 ml target is explicitly an app default. Repeat taps during saving are guarded while intentional later additions remain available. Writes serialize and verify native storage confirmation; Home reads the same source.
- **Daily boundary:** at local midnight the display switches to the new day's records. Previous data is retained. Refresh reloads saved data and goals; it does not add/delete records or generate an AI plan.

Meals are dated individual local records; water is a date-keyed local total. Neither is synchronized to cloud storage. The current UI only browses today: there is no yesterday/date selector, individual water history, or undo. Water remains shared across accounts on a device; changing ownership/storage requires a separately approved plan. No schemas, storage keys or existing records are migrated by this milestone.

## Scope and review

Included: Nutrition host route and Planner/Tracker/Water widgets, existing-theme integration, nutrition data/parser helpers, meal repository fixes, meal/water persistence acknowledgement handling, targeted Gemini meal failures, relevant tests and README/UI/UX documentation. Earlier Planner and circular-tracker work are combined in this approved feature milestone.

Authentication behavior/contracts, other feature screens, dependencies, credentials, root navigation and unrelated repositories are unchanged. The earlier workout strict-response helper is reused for meal requests; workout regression coverage passes. Full file details and root causes are documented in [Planner notes](nutrition-stage1.md), [circular tracker notes](nutrition-water-trackers.md), [audit](nutrition-audit.md) and [repairs](nutrition-repairs.md).

## Publication validation

- Existing branch and origin reviewed; authenticated GitHub account confirmed as `Suboon-stack`.
- Remote fetched and matched local HEAD `c50456a` before preparing this milestone; regular push only.
- All 29 initial pending files backed up before publication edits. No reset/discard or branch switch performed; production/test code is unchanged during publication preparation.
- `dart format`: passed across all 21 changed/new Dart files, no changes required.
- Full `flutter test`: **185 passed** (108 earlier regressions, 44 Planner tests, 33 circular-tracker tests).
- Full `flutter analyze`: **exit 1 with 12 existing unrelated diagnostics** (5 warnings, 7 infos) in unchanged Profile, Progress, Settings and ProgressRepository files. No errors or changed-file diagnostics; the full command is not claimed to pass.
- Scoped `flutter analyze`: **passed with no issues** across all 21 changed/new Dart files.
- `git diff --check` and documentation-link validation: passed. Production/test files match the pre-publication backup; only documentation was updated while preparing this commit.
- Secret/config/generated-file review: no detected secret matches, generated artifacts, logs or private user data in commit candidates. Local Gemini/Firebase configuration stays ignored; sanitized examples remain available. No new screenshots are claimed.

## Remaining checks and planned work

- Live Gemini/Firebase availability and complete physical-device error cases.
- Actual process-restart persistence, local midnight/resume behavior, TalkBack and full accessibility review.
- Genuine current Nutrition screenshots; capture checklist remains pending.
- Previous-day history UI, account-isolated water/profile/raw Progress statistics and water-entry correction need separate approved work.

Tests use mock services and isolated storage; they do not exercise real user records. Work stops after the approved push; no other feature redesign begins.
