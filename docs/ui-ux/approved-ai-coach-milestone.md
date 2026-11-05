# Approved AI Coach Chat milestone

The owner tested the redesigned Chat on an Android phone and approved its UI/UX. Publication is authorized only to `feature/ai-coach-redesign` in `Suboon-stack/Allen-Fitness-Coach`. No merge to main, force-push, or next-feature work is authorized.

## Included behavior

- Midnight Material 3 interface with an original soft-blue four-point sparkle, Allen / AI Fitness Coach header, compact starter suggestions, selectable formatted replies, bounded composer and accessible send action.
- Single-flight requests and an accurate thinking state; draft preservation when submission is blocked or invalid.
- Dedicated Gemini chat path with a 30-second timeout, structured HTTP/provider error mapping, completed-response validation and fixed app-owned error messages. No raw error URLs, provider details or configured credentials are exposed by chat UI/logging.
- Retry reuses the latest failed question rather than adding a duplicate. Failed/stale exchanges do not enter successful history.
- Temporary verified-session state with immediate invalidation on account/session changes, route pop and disposal. No chat persistence is added.
- Bounded Gemini context: eight successful complete exchanges and at most 16,000 UTF-16 text units including prefix/current prompt. Inputs cap at 4,000 and visible replies at 12,000 text units. Old visible messages can remain outside current model context.

Design rationale/component details are in [AI Coach redesign](ai-coach-redesign.md); root causes and repair evidence are in [AI Coach repairs](ai-coach-repairs.md). User approval is recorded without inventing research results or complete live-service/device test coverage.

## Pre-push review

- Branch and remote verified: `feature/ai-coach-redesign`, `https://github.com/Suboon-stack/Allen-Fitness-Coach.git`; authenticated GitHub account `Suboon-stack`.
- Existing approved worktree started from `27a6064`, the previously merged main milestone. The initial 15 pending Chat files were backed up before publication preparation. No reset/discard or branch switch occurred.
- All pending changes are Chat presentation/state/service/test/documentation work. Of existing Dart files, only ChatPage and AiService differ from the pre-chat baseline. Workout/meal behavior is preserved and regression-tested; authentication, other feature screens, repositories, storage schemas, dependencies, user records and central palette are unchanged.
- Publishing preparation changes documentation only; production/test files match the approved pre-publication backup.
- Security scan of tracked/untracked candidates found no exposed credential patterns or generated/environment/private artifacts. Local Gemini/Firebase configuration remains ignored. No new screenshots or actual conversation records are included.

## Executed validation — 2026-11-05

- `dart format`: **passed**, nine changed/new Dart files, zero formatting changes required.
- Full `flutter test`: **242 passed**, including all 185 previous regressions and 57 Chat tests. No test failures.
- Full `flutter analyze`: **exit 1 with 12 pre-existing diagnostics** (5 warnings, 7 infos) in untouched Profile, Progress, Settings and ProgressRepository files. No errors or new Chat diagnostics. Full analysis is not claimed to pass.
- Scoped `flutter analyze`: **passed, no issues** across all nine changed/new Dart files.
- `git diff --check` and documentation-link validation: passed. Approved production/test files are unchanged during publication preparation.

## Known limitations and remaining verification

Chat history is temporary and clears when the route/session ends. Context is bounded; not every older visible message is necessarily sent again. Formatting supports a text-only subset rather than a complete Markdown/web renderer. No streaming, saved archive, automatic personal-record attachment, or backend migration is added.

The API key remains in the installed client and outgoing Gemini request. Safe errors and git-ignored configuration do not prevent key extraction; backend-mediated key management requires a future approved architecture milestone. Provider-side processing cannot be guaranteed cancelled after a request has been received. Injected HTTP clients remain caller-owned; stale responses are still rejected locally.

The owner's Android UI/UX approval is separate from complete live-service/quota, transport-error, account-switch and TalkBack verification. Tests use mock HTTP and fake authentication, never real user records or live API calls. Current genuine Chat screenshots are still pending.
