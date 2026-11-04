# Nutrition Stage 1 — functionality repairs

Root causes were explained before implementation; visual decisions are recorded separately in [Stage 1 design notes](nutrition-stage1.md).

| Root cause | Targeted repair | Verification |
| --- | --- | --- |
| Meal generation catches provider errors and silently returns fixed food plans | Strict meal path with safe HTTP/quota/network/timeout/blocked/truncated-response failures; no meal fallback | Mocked HTTP 401/403/429/500, malformed/blocked/truncated/empty payloads, timeout and network tests |
| Parser trusts strings and silently discards bad lines | Pure typed parser, complete Breakfast/Lunch/Dinner/Snack set, positive integer kcal and finite nonnegative grams; markdown tables supported | Valid four-/six-field responses, invalid numbers, incomplete/duplicate slots, unexpected text |
| Generated data lacks confirmed macros and cannot be logged | Review each suggestion before explicitly logging for today; supplied values editable, missing carbs/fat blank and required | Unknown macro validation, cancellation, edited-name/calorie persistence and summary assertions |
| Unchecked concurrent generation/save taps and uncertain save retries | Single-flight UI, stable per-suggestion UUID, idempotent repository create and serialized meal mutations | Repeated callbacks, concurrent saves, retry after write confirmation loss, unchanged form values |
| Stored account IDs not used by reads | Filter on existing userId before deserializing or limiting results | Two accounts and unowned legacy record; raw records retained, foreign-ID collision rejected |
| Daily totals based on latest-50 history | Unbounded internal date/total reads; public history retains limit=50 | 55 same-day records plus another day, exact calories/macros and list agreement |
| Read exceptions swallowed as empty | Safe repository exception; refresh/history error surfaces; no cleanup of corrupt bytes | Corrupt JSON read/save tests and unchanged raw storage assertion |
| Native write result ignored and optimistic preference cache mistaken for confirmed data | Check meal write acknowledgement, reload after uncertain writes, require reload before retry reads | Mock native false/throw/reload failure and simulated preference restart |
| Route callbacks can arrive after disposal or an account change | Mounted/session checks for new Planner work, parent refresh safety | Late generation after dispose and account-change tests |
| Existing Tracker overflows at enlarged text | Wrap summary labels, expand dropdown; retain existing palette/layout intent | Whole-route 320px and landscape tests at 200% text, both system brightness modes |

## Compatibility boundary

- No existing model fields, repository method signatures, storage key names, authentication behavior, Firebase settings, credentials, or dependencies change.
- Existing `meals` JSON list still holds id, userId, name, mealTime, calories, protein, carbs, fat, date, notes, and createdAt. No migration or data deletion is run. Existing extra fields are preserved on update.
- `createMeal` honors nonempty UUIDs for idempotent retries; callers with an empty ID still receive a generated UUID. The existing Tracker manual action now catches save failures and prevents overlapping submissions; full validation remains deferred.
- Meal reads now throw on corruption and filter by existing userId. Unowned records remain stored but are not assigned to the currently signed-in account. This is a read-filter correction, not a storage ownership migration.
- Only meal read/write paths changed in LocalStorageService. Workout, water, profile and weight persistence paths remain unchanged.
- AiService keeps its Gemini endpoint/model and chat/food-analysis behavior. Its existing strict response/error extractor is shared by workouts and meals; the workout tests remain part of the full regression suite. Quote fallback is retained; the earlier test promising meal fallback was replaced because removing it is intentional.
- Home source and routes are unchanged. The route test now expects the reviewed Nutrition shell to use Midnight; remaining legacy feature-route expectations stay intact.
- ProgressRepository still reads raw records for its own statistics. Water still uses shared date-only totals. Whole-app account isolation is explicitly unresolved.

Generated suggestions are in-memory. There is no saved daily-plan schema; logging a reviewed suggestion creates an actual meal entry only after the user confirms they ate it today. Logged meals persist, but an unsaved suggestion plan is not promised to survive leaving the route or restarting.

## Subsequent circular tracker repairs

The owner subsequently requested both Tracker and Water redesigns. Their [separate root-cause table](nutrition-water-trackers.md#data-and-targeted-fixes) documents configured-goal validation, the single daily meal snapshot, rejection of missing recorded macros, validated manual entry, water mutation serialization/acknowledgement recovery, Home read consistency, and day/resume refresh. Earlier Planner logic is preserved. Date-only water ownership/history limitations remain; no storage migration or new goal storage is authorized.
