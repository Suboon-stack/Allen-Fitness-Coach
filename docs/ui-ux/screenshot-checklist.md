# Before / after screenshot checklist

Use the same Android emulator, dimensions, system brightness, font scale, and keyboard state for each pair. Record build/commit and device in captions. Review captures for personal information before sharing. Never include passwords, tokens, or real account details.

A checklist entry is not evidence of a captured screenshot or usability study. Any screenshots included in `screenshots/` must be actual renders; do not substitute design mockups for implemented screens.

| Capture | Before | After | Comparison focus |
| --- | --- | --- | --- |
| Welcome, light mode | Pending | Captured: `screenshots/welcome-light.png` | Composition, hierarchy, CTA reachability |
| Sign in, empty | Pending | Captured: `screenshots/sign-in-light.png` | Labels, action prominence, spacing |
| Registration, empty | Pending | Captured: `screenshots/registration-light.png` | Field grouping and account switching |
| Password reset, empty | Pending | Captured: `screenshots/password-reset-light.png` | Old dialog vs dedicated route |
| Empty registration validation | Pending | Captured: `screenshots/registration-validation-light.png` | Actionable field errors |
| Login with keyboard | Pending | Pending | Scroll/access to primary action |
| Dark mode | Pending | Pending | Contrast and coherent surfaces |
| 200% system text, 320px width | Pending | Widget-tested, capture pending | Reflow and touch targets |
| Wide split composition | Not previously present | Widget-tested, capture pending | Brand/form balance |
| Request pending / error | Pending | Widget-tested, capture pending | Draft retention and recovery |
| Reset completion | Pending | Widget-tested, live delivery pending | Confirmation and return action |

Record image filenames and capture status here as images are actually produced. Home and other fitness screens are not part of this review.

## Captured artifacts

These are actual 1080×2400 renders from the isolated Android 36.1 emulator at default font scale. The registration capture shows field validation without submitting credentials. Before captures are still pending; the earlier capture attempt found the original emulator signed in on Home, so no authentication baseline pair is claimed. The final captures include the corrected Android status-bar contrast.

## Workout Planner — UI approved; functionality/captures tracked separately

The existing `docs/screenshots/workout-generator.png` and `docs/screenshots/workout-history.png` are actual legacy Android captures and can serve as clearly labeled before references. They have been inspected, not replaced. Match dimensions/theme/font size where practical when producing after captures.

| Capture | Before reference | After status | Focus |
| --- | --- | --- | --- |
| Planning controls | `../screenshots/workout-generator.png` | Pending | Dropdowns, duration choices, primary action |
| Generated session | `../screenshots/workout-generator.png` | Widget-tested; screenshot pending | Plan summary, compact rows, supplied instructions, save actions |
| Generation loading / retry | No baseline capture | Widget-tested; screenshot pending | Single request, helpful error, no fallback workout |
| Saved ready/completed sessions | `../screenshots/workout-history.png` | Widget-tested; screenshot pending | Filters, expandable details, explicit status |
| Completion and restart | Legacy history reference only | Persistence tests passed; real restart/capture pending | Same UUID, no duplicate records, Home/Progress counts |
| Delete confirmation | No baseline capture | Widget-tested; screenshot pending | Cancel and clear destructive action |
| 320px / 200% text, both themes | No paired capture | Widget-tested; screenshot pending | Readable controls and reachable save/completion actions |

Store actual after captures under `docs/ui-ux/screenshots/workout-*.png` once reviewed. Do not substitute fixture screenshots or AI-generated plans as evidence of live Gemini functionality. The owner reports Android UI approval. No new workout screenshots or complete functionality verification are claimed in this checklist.

## Unified Midnight theme — Android UI approved; captures pending

Earlier green/Performance Studio captures remain historical references, not evidence of the new palette. After captures must be actual Android renders; do not recolor old screenshots or substitute mockups.

| Area | Capture focus | Status |
| --- | --- | --- |
| Welcome | Capitalized Allen wordmark, blue movement ribbon, safe-area actions | Owner UI-approved; capture pending |
| Login | Labels, focused field border, password toggle, disabled loading | Automated behavior/contrast checked; device capture pending |
| Registration and reset | Shared typography, validation, loading, confirmation | Automated behavior checked; device capture pending |
| Home | Preserved compact layout, two-column metrics, active bottom item | Automated layout/route checks; device capture pending |
| Workout Plan | Selected/unselected/disabled duration, save states | Automated state/contrast checks; device capture pending |
| Saved Workouts | Filters, status labels, expanded details, delete dialog | Automated state/dialog checks; device capture pending |
| Untouched routes | Legacy styling retained; return restores Midnight | Automated route-boundary checks; manual full-screen review pending |

Use filenames such as `docs/ui-ux/screenshots/midnight-home.png` and `midnight-workout-plan.png`. Record system brightness and text scale, and review screenshots for personal information before sharing. The owner has approved the latest Midnight UI on Android, including the Welcome graphic and “Allen” wordmark. Actual screenshot files, TalkBack, and full functionality checks remain separate and pending. See [milestone validation](approved-midnight-milestone.md).

## Nutrition Stage 1 — historical capture checklist

At the Planner-stage checkpoint, only Planner and the shared shell used Midnight; Tracker/Water were deferred. The later circular-tracker stage below supersedes that scope. See the [actual Android capture checklist](nutrition-stage1.md#screenshot-checklist). Initial preferences, supplied results, review/keyboard/validation, error recovery, and logged-state captures are all pending. No new screenshots or owner approval are claimed.

## Circular Nutrition and Water — feature approved; captures pending

The owner requested both trackers after the Planner stage. [Capture/checklist details](nutrition-water-trackers.md#screenshot-checklist): recorded totals, no-goal state, manual entry/keyboard/validation, Water default-goal/quick-add states, large text and recovery. The owner has approved the feature and authorized branch publication. All new captures remain pending. Earlier Nutrition screenshots are before references; no additional process-restart, accessibility or live-service test result is claimed. See the [approved milestone](approved-nutrition-milestone.md).

## AI Coach Chat — UI/UX approved; captures pending

Capture the original sparkle/header, empty suggestions, real conversation formatting, pending send, sanitized retry, and small-screen keyboard/large-text states. [Detailed checklist](ai-coach-redesign.md#screenshot-checklist). The owner has tested and approved the UI/UX on Android. Actual capture files remain pending; no additional test results are claimed. Use actual Android renders and remove personal text; fixtures/mockups do not establish live Gemini functionality.


## Food Scanner — owner-approved on Android; captures pending

Reference: owner-supplied `Allen Food Scanner UI Concepts.png`; do not use it as implemented-app evidence. The owner reports completing Android testing and approves the implementation/UI/UX. Capture genuine Android screenshots; none have been added to the repository. The unchecked items below remain capture/regression reminders, not claims about individual tests the owner performed.

- [ ] Before: historical scanner screenshot, labeled as the original UI.
- [ ] Dashboard with Allen sparkle, both source actions, no invented recent scans.
- [ ] Real camera preview with frame, shutter, gallery and supported lens switch.
- [ ] Permission denied / camera unavailable with gallery alternative.
- [ ] Local photo review before upload; cancellation returns safely.
- [ ] Active analysis and sanitized network/quota/invalid-response retry.
- [ ] Actual Gemini result with AI Estimate badge, calories/macros and supported identified items only.
- [ ] Keyboard-safe editing, invalid value feedback, quantity explanation.
- [ ] Explicit saved confirmation and Nutrition showing matching values / AI Estimate label.
- [ ] Reopen app and confirm the logged meal remains with no duplicate after repeated taps/retry.
- [ ] Small Android, landscape, 200% font, TalkBack, system bars and keyboard.
- [ ] Background/resume, Back during capture/analysis and account switch; old results never reappear.

Mocked widget previews/fixtures are automated tests, not live Gemini or native-camera evidence.


## Progress Tracking — implementation approved; captures pending

Use the owner's `Dark Navy Fitness Progress Dashboard.png` as a concept reference only. The owner approved milestone finalization on 6 November 2026. No detailed device-test results or screenshot evidence were supplied, so the unchecked items remain capture/regression reminders.

- [ ] Original tabs/chart and legacy weight flow, labeled as before screenshots.
- [ ] Your Journey mountain banner with a real recorded summary.
- [ ] Dated chart with all four filters, point inspection and accessible details.
- [ ] Empty period and single-point states without invented measurements.
- [ ] Key metrics with actual targets; unavailable water and missing-goal explanations.
- [ ] Genuine completion, weight and meal timeline events with dates.
- [ ] Keyboard-safe logging/editing, validation, explicit deletion and saved refresh.
- [ ] Legacy/unowned data remains preserved; owned data differs between accounts.
- [ ] Loading, partial error, retry, stale response and account-switch behavior.
- [ ] Small screen, landscape, 200% text, safe areas and TalkBack.

Capture genuine Android renders after installation, record the device/build and remove private notes/account information. Temporary test-fixture renders do not demonstrate native storage, live Firebase behavior or real-device appearance.

## Profile & Settings — owner-approved; captures pending

Reference: `Profile Settings Redesign Trio.png`. Capture actual app renders; the concept is not implementation evidence.

- [ ] Before: legacy profile editor, notification toggle and data/account controls.
- [ ] Profile identity/initials, owned statistics and an actual saved goal; redact name/email.
- [ ] Profile with no local details/weight/goal, loading, sanitized error and retry.
- [ ] Personal-details editor, optional targets, BMI, invalid inputs and keyboard-safe Save.
- [ ] Two accounts with different saved profiles/targets and no foreign statistics.
- [ ] Legacy profile bytes retained, unowned records excluded, no automatic claiming.
- [ ] Settings groups, fixed appearance/units/language and system reduced motion.
- [ ] Android notification permission allowed/denied, explicit test, settings return/restart.
- [ ] Account & Security reset success/error/loading and sign-out failure/success.
- [ ] Data & Privacy account-only export confirmation and shared-water explanation.
- [ ] About, five-destination navigation and return to an existing Workout Saved tab.
- [ ] Small phone, landscape, 200% font, TalkBack, keyboard and system insets.

Suggested paths: `screenshots/midnight-profile.png`, `midnight-settings.png`, `midnight-account-security.png`, `midnight-profile-edit.png`, `midnight-data-privacy.png`. Remove personal data and record device/build. The owner approved the UI and functionality for GitHub finalization on 6 November 2026. Individual device-matrix results and screenshots were not supplied; unchecked items remain capture/regression reminders.
