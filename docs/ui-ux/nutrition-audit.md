> Audit snapshot before the Planner stage. The later owner-requested [circular Nutrition/Water stage](nutrition-water-trackers.md) implements the previously deferred Tracker, manual logging and Water UI/repair work locally. Water ownership migration and individual-entry storage remain unimplemented and require approval.

# Nutrition audit and staged scope

Evidence: existing Dart source, repository/storage inspection, and automated tests. No user research, usability study, live Gemini success, or owner approval of this new feature is claimed.

Git baseline: clean working tree on `redesign/performance-studio-auth`, HEAD `c50456a65a6c2d871f5be7c8fc41d28d911fd295` (previous approved UI milestone, already pushed). No branch switch, reset, commit, push, dependency change, or credential change is part of Nutrition Stage 1.

## Existing experience

Nutrition is one route, `MealPlannerPage`, reached from Home. It has Tracker, Planner, and Water tabs. Tracker combines fixed-target macro bars, an always-visible six-field meal form, and today's records. Planner stacks chip groups, a calorie slider, generation, and decorative meal cards. Water has a large total, three quick-add buttons, and a hardcoded daily target. Food Scanner is a separate route and is outside this feature stage.

Existing goals: Lose Weight / Gain Muscle / Maintain. Diet choices: No preference / Vegetarian / Vegan / High Protein / Low Carb. The original calorie slider covers 1200–4000 in 100-kcal steps. These are planning preferences, not personalized recommendations.

## Confirmed findings

| Area | Source observation | Disposition |
| --- | --- | --- |
| Generation | Gemini failures return predefined meals without disclosure | Stage 1: remove meal fallback; show retryable safe errors |
| Parsing | Lines without enough cells disappear; other cells remain unchecked strings; empty results still mark success | Stage 1: all-or-error typed parser; four meal slots and valid supplied numbers required |
| Generated saving | Planner has no persistence action; MealPlanItem omits carbs/fat while Meal requires them | Stage 1: review and log individual meals; unknown macros require input, no invented zeroes |
| Request state | Valid results cleared before generation; no duplicate guard in method or mounted checks after await | Stage 1: retain last valid result, immutable preference snapshot, single-flight and session checks |
| Reads | MealRepository ignores userId, assigns missing ownership to current caller, catches unreadable data as empty | Stage 1: filter existing owner IDs and surface failures; unowned records remain stored |
| Summaries | Date queries and calorie totals use the latest 50 meals rather than all applicable records | Stage 1: aggregate all matching owned records; retain latest-50 history API |
| Writes | New UUID for every retry; whole-list mutations can race; native acknowledgement ignored | Stage 1: stable generated-draft ID, serialized meal mutations, meal-only acknowledgement/reload checks |
| Manual logging | Invalid/blank numbers become zero; drafts clear only after await; no validation or loading design | Stage 1 adds a submission guard/error recovery required by repository errors; full form/validation redesign remains Stage 2 |
| Existing reflow | Tracker summary rows and dropdown overflow with enlarged text | Stage 1: minimal wrapping/expanded-dropdown corrections, preserving legacy presentation |
| Water | Home and Nutrition both read ProgressRepository → LocalStorageService, but water_YYYY-MM-DD keys have no owner; writes lack guards, serialization, and native acknowledgement | Stage 2: water UI and persistence repair; account ownership requires a separately approved storage decision |
| Targets | Macro targets 150/250/65 g and water target 2000 ml are hardcoded; Planner calorie choice controls Tracker target | Stage 2: clarify supported targets and replace misleading summary composition |
| History/edit/delete | UI only shows today's records; repository has update/delete APIs but no user-facing editing/deletion flow | Stage 2: review logging/history scope and add explicit actions with confirmation |
| Legacy progress | ProgressRepository reads raw meal/workout arrays without ownership filtering | Outside Stage 1; source unchanged, global account isolation is not claimed |

## Manageable stages

1. **Planner tab and required reliability changes (implemented locally; awaiting review).** Midnight shell, compact preferences, generation feedback, readable suggestions, review-and-log sheet, and necessary meal repository/persistence repairs. Tracker and Water keep their earlier presentation under an explicit legacy theme boundary. Existing routes and tab order remain.
2. **Tracker / nutrition overview / manual meal logging (not started).** Compact recorded-value summaries, validated logging and review/history actions; preserve previously entered records.
3. **Water (not started).** Clear daily quantity, reliable duplicate-safe writes, Home consistency checks. Before any owner-aware key/schema or migration work, explain legacy ownership and request approval for the concrete storage decision.

Existing raw meals are not migrated, removed, or reassigned. Filtering by already-stored userId changes visibility: unowned legacy meals no longer appear as the current user's entries. A later ownership recovery process requires an explicit decision. Water and unrelated profile/weight/workout ownership are not repaired by this filtering.
