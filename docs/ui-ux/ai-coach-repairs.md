# AI Coach Chat — targeted repair record

Visual decisions and device review steps are in the [redesign notes](ai-coach-redesign.md). Repairs below address the owner-approved audit without changing chat persistence or the authentication/repository architecture.

| Confirmed root cause | Repair | Automated evidence |
| --- | --- | --- |
| Send and keyboard actions can start another request while loading | Controller and service both guard a single active request; send button disabled while pending | Overlapping service calls, repeated UI/keyboard submission, retained next draft |
| One loading boolean becomes false when the first of overlapping requests returns | Only the active controller generation may finish the current turn | Busy guards, stale-response handling, accurate thinking state |
| Page calls setState after awaiting without mounted checks | No asynchronous widget mutation; controller owns results and is invalidated on pop/disposal | Leave/reopen while pending; completion after disposal and immediate navigation abandonment |
| Successful old-account response can update a retained chat instance | Verified-owner binding and generation invalidation; messages/drafts/context reset on identity/unverified-session changes | Account A→B→A, old result while new request pending, widget account switch |
| Chat never applies the existing generation timeout | Separate 30-second chat timeout; owned transport closes when timed out/reset | Timeout followed by a late response; retry context excludes old result |
| Parsing directly indexes first text part | Validate root/candidate/finish reason/parts, join visible multipart text, exclude thoughts, reject blocked/empty/malformed/truncated responses | Missing fields, blocked feedback/rating, MAX_TOKENS, malformed JSON/text, multipart/thought handling |
| Errors are raw strings inside normal assistant messages | Typed failure enum mapped to fixed UI copy; provider status/code classification, no raw message/URL display or logging | HTTP 400/401/403/408/429/500/503/504, error payloads, private transport URLs, unexpected exceptions, configured-key echo rejection, captured-log assertion |
| Quota checks search ordinary response words | Interpret HTTP/structured provider errors rather than text content | Valid reply containing quota/429 remains a valid answer |
| Unbounded conversation array is resent and failed prompts diverge between UI/service | Bounded complete successful pairs; failures never commit to context; Retry reuses the same question ID | Eight-turn/16k-character budget checks, whole-pair trimming, failure/retry prompt count |
| Retrying older failures after newer turns could reorder model context | Only the latest failed turn offers Retry; older failures stay visibly marked | Attempt to retry an earlier failure after a later successful turn |
| Forced delayed scrolling interrupts reading | Post-layout follow only near the bottom; remove delayed timers/forced animation | Long reply, bottom visibility, viewport stability while reading earlier messages |
| Composer grows without bound and ignores explicit safe-area handling | Adaptive 1–4 lines, scrollable draft, keyboard resizing and SafeArea | 320/360 portrait and 800px landscape, 200% text, route Back button, 24px insets and keyboard |

## Preservation checks

Workout/meal public method signatures, generation prompts, endpoint/model and timeout/error behavior are retained. Their private helper no longer needs the old unbounded chat-history branch because chat is isolated; their request contents still consist of the existing prefix plus their current prompt. Quote fallback and food-analysis code remain unchanged. Tests explicitly make chat followed by workout/meal/quote calls on one AiService and verify chat context is absent from non-chat payloads.

No AuthCubit/AuthRepo/Firebase behavior, user record, SharedPreferences key, repository operation, dependency, or unrelated screen is changed. Chat state is memory-only. No client-to-backend migration is included.

## Remaining security work

Direct client use still requires the API key in the installed app and outgoing request. Safe error mapping and ignored source files do not prevent extraction or unauthorized use of that key. A future approved backend/key-management design is needed; no security certification or complete key protection is claimed here. Default transports are closed locally when abandoned, but provider-side processing cannot be guaranteed cancelled.

## Approval and publication

The owner has reported Android UI/UX testing and approval and authorized the feature-branch commit/push. These repair claims are supported by the documented automated tests; approval is not presented as verification of every live-service, cancellation or accessibility edge case. See [publication validation](approved-ai-coach-milestone.md).
