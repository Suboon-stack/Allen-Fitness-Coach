# AI Coach Chat — Midnight redesign

Status: the owner tested and approved the AI Coach Chat UI/UX on Android and authorized committing/pushing to `feature/ai-coach-redesign`. Merging into main is not authorized. Implementation started from synchronized main/origin main at `27a6064` with a clean working tree. See the [approved milestone validation](approved-ai-coach-milestone.md).

## Brief and evidence

The owner approved the code audit and requested reliable chat, the existing Midnight identity, temporary conversations, and an original four-point sparkle beside Allen. Decisions below reflect that brief and source inspection. The owner has since reported Android UI/UX approval. No user study, measured usability improvement, new screenshot, or additional device-test result is invented.

The previous page used the legacy gray palette, a permanently green status dot, plain message maps, unbounded input, forced delayed scrolling, and no distinct failure/retry state. Requests could overlap, responses could arrive after leaving the page, and chat lacked the validation/timeouts already present for workouts/meals. Repair causes are recorded separately in [AI Coach repairs](ai-coach-repairs.md).

## Composition and components

- **Header:** functional Back navigation, a compact 40px navy rounded square with a 20px four-point sparkle, Allen as the primary title, and AI Fitness Coach as the subtitle. The sparkle is an original monochrome CustomPainter path using the existing secondary token `#AFC4FF`; it is not Google's logo asset. No robot, online-status dot, gradient, shadow or repeated avatar is added. Header height/subtitle wrapping adapt to large text.
- **Empty state:** Ask Allen, a short description of workouts/nutrition/routines, and three compact suggestion chips. Chips populate the composer rather than make an unsolicited request. They do not overwrite an existing draft. A short note explains that chats are not saved in Allen.
- **Conversation:** a constrained 720px content column. User bubbles use the existing primary blue with onPrimary text; Allen replies use the navy surface with light text. Both are selectable. Fixed spacing and restrained 12px corners replace decorative borders.
- **Formatting:** text-only rendering supports paragraphs, bullet/numbered lists, headings, bold, inline code and simple fenced code. HTML is literal text. No remote images, links with navigation actions, scripts, provider-defined widgets, or new formatting dependency are introduced. This is intentionally not a full Markdown renderer.
- **Composer:** a rounded field and a 52px Material send button with an accessible label. One to four visible input lines adapt to available height and font scale; longer drafts scroll inside the field. SafeArea and keyboard-resized constraints keep controls usable. Keyboard Send uses the same submission guard as the button. A rejected/pending submission preserves its draft; accepted input moves into a user bubble.
- **Loading/errors:** a subtle live thinking label in the thread, accurately tied to the active request. Failures are labeled under the original user message, not presented as successful assistant replies. Retry updates that message rather than appending it again. It does not erase an unsent composer draft. Only the most recent failed turn can be retried; continuing with another question leaves earlier failed turns marked but prevents retroactive context reordering.
- **Scroll behavior:** post-layout following happens only when the user was within 96 logical pixels of the bottom. No forced animated scroll interrupts earlier reading. Following uses layout jumps and no timed animation, so reduced-motion settings do not introduce a chat-specific motion loop. Long-reply and reading-history cases have widget coverage.

All colors, typography, control styling, spacing and widths reuse the existing Material 3 theme/tokens. Root navigation and unreviewed screens are unchanged.

## State and request behavior

`ChatMessage` uses typed roles/status/failure codes. A small ChangeNotifier controller owns the temporary conversation and single-flight state; AuthCubit remains the authentication source. The controller checks identity, invalidates request generations on account/session changes, and abandons requests immediately on route pop or disposal. Messages/drafts are cleared on an identity/verification change; a new route starts fresh.

`AiService.chat` delegates to a dedicated chat session. Existing workout, meal, quote and food-analysis behavior stays on its earlier path. The obsolete unbounded shared chat-history branch was removed from that private non-chat helper; non-chat requests still send the same prefix and current prompt, with no chat context. Regression coverage explicitly exercises shared-service chat followed by workout/meal/quote requests.

Chat uses the existing Gemini endpoint/model with a 30-second timeout. It reads structured HTTP/provider statuses, validates completed STOP responses, rejects blocked/truncated/empty/malformed output, joins visible text parts and excludes thought parts. Fixed application messages replace exceptions, URLs and provider details. A response containing the configured credential is rejected rather than displayed or retained. Chat code adds no request/error logging.

Response validation follows the provider's documented [response fields and finish reasons](https://aistudio.google.com/api-reference/generate-content); HTTP/status mappings use its [error guidance](https://aistudio.google.com/docs/troubleshooting). No live request was made while building these tests.

## Bounds and temporary context

- Maximum submitted prompt: 4,000 UTF-16 code units. Oversized input remains editable and is not silently truncated.
- At most eight successful user/assistant pairs are retained as Gemini context.
- Sent text content is limited to 16,000 UTF-16 code units including the instruction prefix and current prompt. Oldest complete pairs are removed to fit; these are character bounds, not a token-count claim.
- Visible replies are limited to 12,000 UTF-16 code units; malformed/oversized output is rejected.
- Failed, timed-out, blocked, truncated and stale replies do not enter successful context. Only valid completed exchanges are retained.
- The on-screen temporary thread may still show older successful messages that are outside the model's bounded context. Nothing is written to SharedPreferences or Firebase. No archive, automatic fitness-record attachment, attachments, streaming, or backend migration is added.

## Security boundary and limitations

Safe UI errors do not secure a bundled credential. The API key still comes from the ignored client-side secrets file and is included in the direct Gemini request URL. A key inside an installed client can be extracted; backend-mediated requests/key protection require a separately approved architectural milestone. No credential/configuration value is printed, committed, or changed here.

The default chat session owns its HTTP client and closes it on completion/timeout/reset. Injected test/shared clients remain caller-owned. Epoch guards discard late results even when an injected transport cannot be physically cancelled. Client-side cancellation does not guarantee that the provider stops processing a request already received. No automatic retries or hidden background requests are made.

Identity guards use the current AuthCubit verification state; no Firebase authentication behavior, repository contract, storage schema or dependency changes are introduced. The owner’s Android UI/UX approval is recorded separately from complete live-service, TalkBack, account-switch and transport-cancellation verification, which remain tracked device checks.

## Android testing checklist

1. Install `build/app/outputs/flutter-apk/app-debug.apk` over the existing debug app without clearing data. Sign in and open Ask Allen from Home; verify the sparkle/header and consistent Midnight colors.
2. Try a suggestion chip: it should fill the composer without sending. Enter your own question and send with both the button and keyboard. Rapid/repeated submission during a request should not create another turn, and your next typed draft should remain.
3. Inspect a real reply: selectable paragraphs/lists, readable blue/light contrast, correct thinking state. Try a long reply and a long draft. Check small portrait/landscape, large system text, gesture/navigation insets and the visible keyboard.
4. With a real connection failure, confirm a safe message and Retry. Retry must reuse the original question rather than add a duplicate; typing another unsent draft must not be lost. API/quota errors should contain no request URL, key, raw exception or provider details.
5. While a reply is pending, press Back; reopen Chat and confirm it starts empty. Repeat logout/account changes when practical. Earlier replies/drafts must not appear in the new session.
6. Read earlier messages while a new reply arrives: the viewport should stay in place. At the bottom, new messages should remain reachable/visible. Review TalkBack labels, selection, focus order, and reduced-motion settings.
7. Verify workout generation/saving, Nutrition generation/logging and Home navigation still work. These features were not redesigned in this milestone.

## Screenshot checklist

Capture actual Android renders after review, recording device/build/font scale. All new captures are pending; no fixture or mockup is evidence of a live Gemini result.

- `screenshots/ai-coach-empty-midnight.png` — sparkle, header, compact introduction and suggestions.
- `screenshots/ai-coach-conversation-midnight.png` — real user/reply formatting, without private information.
- `screenshots/ai-coach-thinking-midnight.png` — pending request and disabled send.
- `screenshots/ai-coach-retry-midnight.png` — sanitized error and retained question/draft.
- `screenshots/ai-coach-keyboard-midnight.png` — small Android screen with keyboard/large text.

## Validation

Executed on 2026-11-05:

- `dart format`: passed; final no-change verification covers all nine changed/new Dart files.
- Scoped `flutter analyze`: passed with no diagnostics across chat source and tests.
- Full `flutter analyze`: exit 1 with the same **12 pre-existing diagnostics** (5 warnings, 7 infos) in unchanged Profile, Progress, Settings and ProgressRepository source. No new diagnostics or errors remain. Full-project analysis is not claimed to pass.
- Full `flutter test`: **242 passed**, including **57 new chat tests** (33 service, 8 controller, 16 widget) and all 185 previous regressions.
- `flutter build apk --debug --no-pub`: passed. Review artifact: `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` and local documentation-link checks: passed.
- Protected-source hash checks: only ChatPage and AiService changed among existing Dart source/tests. Authentication, other feature screens, all existing tests, repositories, storage services, theme tokens, and dependency files match the pre-chat snapshot.
- Sensitive-pattern scan found no credential/private-key matches in changed/new files. Chat runtime code contains no print/debug logging calls.

Tests use mock HTTP clients and fake authentication; they do not contact live Gemini/Firebase or user records. Those were implementation-stage checks. The owner has since approved the UI/UX on Android and authorized this feature-branch publication. Live model availability/quota, complete transport/account-switch behavior and TalkBack remain tracked checks; no new screenshots or detailed device results are invented. Current pre-push checks are recorded in the [approved milestone](approved-ai-coach-milestone.md).

## Modified files

Production:
- `lib/fitness/pages/chat_page.dart` — redesigned chat, composer/scroll/layout, authentication and navigation integration.
- `lib/fitness/services/ai_service.dart` — dedicated chat delegation/reset and configurable chat timeout; non-chat behavior preserved.
- `lib/fitness/models/chat_message.dart` (new) — immutable typed messages/status and sanitized failure codes.
- `lib/fitness/controllers/chat_controller.dart` (new) — single-flight temporary message state, retry and lifecycle guards.
- `lib/fitness/services/gemini_chat_session.dart` (new) — structured validation/errors, timeout and bounded successful context.
- `lib/fitness/widgets/chat_widgets.dart` (new) — original sparkle, selectable safe formatting and message/error presentation.

Tests (new):
- `test/chat/gemini_chat_session_test.dart`.
- `test/chat/chat_controller_test.dart`.
- `test/chat/chat_page_test.dart`.

Documentation:
- `README.md`.
- `docs/ui-ux/README.md`.
- `docs/ui-ux/midnight-theme.md`.
- `docs/ui-ux/screenshot-checklist.md`.
- `docs/ui-ux/ai-coach-redesign.md` (new).
- `docs/ui-ux/ai-coach-repairs.md` (new).
