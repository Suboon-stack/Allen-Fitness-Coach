# Workout-specific repairs

This file separates behavior fixes from the presentation rationale. These targeted repairs accompany the owner-approved Workout Planner UI. Automated coverage is documented below; complete live-service and real-device persistence verification remains pending.

| Confirmed cause | Targeted fix | Regression coverage |
| --- | --- | --- |
| Completion saved a record but passed an exercise name rather than its UUID | Retain createWorkout's ID, complete that record, and guard missing IDs | Two workouts with the same exercise name; correct-ID assertions; explicit missing-record failures |
| Repeated save/complete actions could create duplicate records | Stable UUID per generated draft, single-flight UI, idempotent create/complete | Rapid taps; repeated/concurrent create; retries after post-write confirmation failure and partial completion failure |
| Whole-list read/modify/write operations could overwrite concurrent changes | Serialize workout mutations across repository instances; release idle queue state after completion | Concurrent creates/completions, queue recovery after failure |
| Completed workouts used their planning date for Home/Progress activity | Set existing date on first completion, preserve createdAt and subsequent completion date | Old plan completed today; weekly stats, streak, minutes, and stable duplicate-completion date |
| Native save result was ignored; preference cache changes before acknowledgement | Workout-only save checks false results, reloads uncertain cache, and requires successful reload before a subsequent workout read | Mock native false return, thrown platform write, failed cache reload, confirmed retry/reload |
| Generation failed silently into predefined workouts | Remove workout fallback; safe workout-only HTTP/network/timeout/blocked/truncated-response errors | Mock Gemini 401/403/429/500, malformed/empty/blocked/truncated content, timeout, network failure |
| Parser assumed split indexes and invented invalid set/rep defaults | Pure all-or-error parser; positive integer reps/sets; no dropped invalid rows or default 3/10 prescriptions | Malformed/missing fields, zero values, ranges/timed holds, markdown tables, optional instructions |
| Saving after editing preferences changed the plan's meaning | Capture generation inputs in the immutable draft | Edit preferences after generation, then verify saved focus/duration |
| History read failure returned an empty list | Throw a safe storage error without deleting or rewriting raw records; cached UI error/retry | Corrupt JSON/malformed exercises, retry recovery, read-count/refresh assertions |
| History completion/delete did not refresh status or expose errors | Explicit mutation state, reload after success, failure messages, delete confirmation | Status filters, completion refresh, cancel/confirm delete |

## Compatibility and scope

- Existing Workout and Exercise fields, SharedPreferences keys, AuthCubit/AuthRepo integration, and repository method signatures remain intact. No migrations or automatic data cleanup run.
- Only LocalStorageService.saveWorkouts/getWorkouts changed in the shared persistence service. Other preference data paths are untouched. This dependency was explained before editing.
- Only the workout generation path enables strict Gemini behavior and its timeout. The model/endpoint and existing chat, meal, quote, and food-analysis functionality remain. Meal/quote fallback compatibility has a regression test.
- Original generated source uses the existing optional notes field. Saved plan details are restored from notes only if they match the persisted exercises; legacy personal notes are shown normally.
- Tests simulate persistence reload and repository recreation. They do not claim to have restarted the user's real Android app or verified a live Gemini request.
