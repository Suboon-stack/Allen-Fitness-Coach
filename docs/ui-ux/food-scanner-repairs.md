# Food Scanner repair record

Functionality repairs are documented separately from visual decisions. Existing authentication, workout/meal generation, repository contracts and storage schemas remain unchanged.

| Confirmed root cause | Targeted repair |
| --- | --- |
| `analyzeFood` returned raw exception/provider strings; the screen searched only uppercase labels, leaving failures with no result/error UI. | Dedicated food-analysis boundary throws typed, fixed app-owned messages. Interpret HTTP/provider status, timeout and network failures; explicit retry; no raw diagnostics or automatic fallback nutrition. |
| Only candidate zero/part zero text was accepted without finish, safety or nutrition validation. Extension-based MIME treated every non-PNG file as JPEG. | Check complete STOP responses, blocking, truncation, visible text parts, strict JSON food/nutrition types, finite nonnegative values and optional identified-food data. Detect JPEG/PNG/WebP by signatures, reject missing/unsupported/over-8-MB files, bound response length. Signature checks do not prove a fully valid encoded image; decoder/provider failures remain possible and are handled. |
| Async picker/analysis called setState without mounted/account/image checks. An old request could update a newer review. | Controller epochs/owner checks plus page selection tokens. Cancel/invalidate on Back, disposal, new selection and unverified/changed account. Current requests alone control loading state. |
| No embedded camera; old picker opened a separate camera app. | Approved official camera dependency; isolated camera boundary, explicit lifecycle ownership, serialized releases, stale initialization/capture guards, permission/unavailable feedback and gallery alternative. |
| Results could neither be corrected nor logged to Nutrition. | Temporary typed editable result; explicit save through existing MealRepository with current owner/category and persisted AI provenance in existing notes. |
| Adding a naive save button would risk duplicates after rapid taps or uncertain native acknowledgment. | Synchronous save guard, stable draft UUID/date, success disables further saves. Retry uses the same ID and reconciles reviewed edits against that record. Existing repository serialized/idempotent writes are reused. |
| Nutrition did not identify photo estimates. | Recognize the scanner's existing-notes prefix and show a small AI Estimate label on those meal rows. View Nutrition opens the existing tracker with the same repository, refreshing from actual records. |

`AiService.analyzeFoodEstimate` uses the same Gemini model/direct request architecture. The old labeled `analyzeFood` entry point remains available as a compatibility wrapper and now throws safe typed failures. Workout generation, meal generation, quotes and chat behavior are untouched. No provider errors, secrets or full image data are printed by scanner code.

No migration or reassignment of existing records is performed. No recent-scan persistence is invented. The client-side Gemini credential extraction risk remains an explicit future architecture issue.
