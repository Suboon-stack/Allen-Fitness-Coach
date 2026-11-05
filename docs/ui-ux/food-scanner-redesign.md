# Food Scanner — Android-tested and owner-approved

## Scope and reference

The owner supplied and approved `Allen Food Scanner UI Concepts.png` on 5 November 2026. It contains a camera-first screen (Design 1), nutrition results (Design 2), and a scanner dashboard (Design 3). This is a visual reference, not a screenshot of implemented Allen functionality. No user research or usability results are claimed.

Implementation is on `feature/food-scanner-redesign`, created from synchronized main after the AI Coach merge (`5e71e67`). After Android testing, the owner approved the implementation and UI/UX on 5 November 2026 and authorized feature-branch publication followed by a normal merge into main if validation and merge checks are acceptable. Keep the feature branch; no new feature work is part of this approval. The dependency was separately approved in chat before installation.

## Original problems

- The old screen mixed choosing a source, analysis, and results in one long page, with no clear review/save flow.
- Legacy hardcoded colors, emoji decorations and a same-color calorie value/background conflicted with the approved Midnight identity.
- No editing or Save to Nutrition action existed. Scanner results were temporary and did not update nutrition records.
- Parsing accepted any matching text lines, with no required nutrition validation. AI errors became empty results rather than actionable feedback.
- Picking/analysis had no disposal or identity checks. An older result could arrive after a photo/account/navigation change.

Repair details are recorded separately in [food-scanner-repairs.md](food-scanner-repairs.md).

## Visual decisions and components

Use the centralized Midnight theme: background `#101827`, surface `#1C2940`, primary `#315CF5`, secondary `#AFC4FF`, text `#F2F5FA`, supporting text `#B2BED0`. Use existing typography, 20 px page padding, 8/16/24/32 px spacing, 12 px surface/control corners, and existing Material 3 button/input styles. No gradients, extra accent palette, or copied logo assets.

- **Entry (Design 3):** original shared four-point Allen sparkle, title/subtitle, centered blue scanning frame/camera, one headline, short explanation, stacked Take Photo/Choose from Gallery actions. The reference's Recent Scans section is omitted: the existing app has no persisted scan history or thumbnails. A meal log is not misrepresented as scan history.
- **Camera (Design 1):** real CameraX-backed preview, subtle vector corner brackets, a 76 px circular shutter, gallery shortcut, switch action only with multiple available cameras. Preview is cropped to fill its viewport; full photo is shown with contain fit on the next review step. Header and capture controls sit outside the preview for legibility. The source reference's duplicate Photo/Gallery selector is omitted because both source actions are already available.
- **Review:** captured/selected photo is local until the explicit Analyze photo action. Explain that analysis sends the photo to Google Gemini. Analysis never saves a meal automatically.
- **Results (Design 2):** image/name/AI Estimate badge and explanation first, one compact calorie/macro surface, identified items only when supplied. The existing general food-tip feature is retained as a small AI note only when provided by Gemini. Edit and Save to Nutrition form the primary action pair. On narrow screens or enlarged text they stack; the summary stacks too. No fabricated food photos, ingredients, portions or values.
- **Editor:** keyboard-safe scrollable sheet; editable food name, optional total quantity, calories and macros, and existing identified-item names/quantities. Items can be removed. Changing quantities does not recalculate nutrition: the explanation asks the user to review total values explicitly. Apply changes only updates the temporary review, not storage.
- **Saved state:** confirm success, remove the save action to prevent repeat submission, offer View Nutrition and Scan another meal. View Nutrition opens the existing tracker and reads actual persisted totals. A small AI Estimate label is the only Nutrition UI addition; its layout is otherwise preserved.

## User flow and persistence

Home's existing scanner route → scanner dashboard → camera/gallery → photo review → explicit analysis → estimate → optional edit → choose existing meal category → explicit Save to Nutrition → existing Nutrition Tracker.

Cancellation returns without analysis or saving. Back from review/results clears the temporary scan and returns to the scanner dashboard; Back from the dashboard returns through the existing route. Back during a save is held until confirmation/error, avoiding ambiguous repeated submission.

Use the existing `MealRepository` and unchanged `meals` records. Retain a draft UUID and first-save date across uncertain acknowledgment/retries. AI provenance, reviewed portions and identified foods use the existing optional `notes` field beginning `AI photo estimate — reviewed by user.` This is not a new schema or migration. Existing records and account ownership fields are preserved. Nutrition recognizes the prefix to display an estimate label; this does not establish independently verified nutrition for other records.

There is no persisted image/scan history, new cloud storage, quantity-based nutrition computation, or new chat context. Unconfirmed results are temporary. Existing image-picker/camera temporary files are not converted into a persistent image archive.

## Dependency and platform impact

The owner approved exact `camera: 0.12.0+2` before installation. The official Flutter plugin supplies embedded preview/capture/lens switching; `image_picker` remains the existing gallery dependency. Resolved native packages use CameraX on Android. Audio is disabled. There is no recording, background streaming, or new microphone request for this feature.

No Android manifest/Gradle changes were required: CAMERA permission already exists, and the installed Flutter default minimum SDK is 24. The dependency lock now resolves an effective Dart >=3.11 / Flutter >=3.41 requirement, satisfied by this workspace's Flutter 3.50 / Dart 3.12 development SDK. The direct camera release itself has a Dart 3.10 minimum; newer releases need stable Dart 3.12. No existing dependency versions were upgraded during installation.

The owner tested and approved the Android implementation. Comprehensive native permission, OEM camera rendering/rotation and lifecycle coverage across devices remains separate; no exhaustive device-testing claim is made. The repository's pre-existing iOS Info.plist has permission entries outside the main dictionary; iOS configuration/build verification is deferred, and no iOS support claim is made here.

## Accessibility and review checklist

- Standard Material buttons, visible field labels, 48 px minimum controls, accessible shutter/gallery/switch names.
- SafeArea for Android insets; all content scrolls on short screens. Adaptive result/actions/macros for enlarged text.
- Fixed app-owned error messages, explicit retry, live loading/success/error semantics. No fake online or verification indicators.
- No animation dependency; progress uses standard Material indicators.
- Test 320×568, 360×640 and landscape with 200% text; manually test actual keyboard, gesture/three-button navigation, TalkBack and contrast on device.
- Capture real app screenshots only after installation; see [screenshot-checklist.md](screenshot-checklist.md). Do not present the supplied concept image or mocked-camera tests as completed-app evidence.

## Remaining limitations

Nutrition from an image is an AI estimate and may be inaccurate. Gemini model availability/quota depend on external configuration. The API credential remains in the client application and can be extracted; sanitizing messages is not a substitute for a future server-side gateway. No backend migration is part of this milestone.

Account changes invalidate temporary results and prevent new saves under the wrong identity. An already-started local write cannot be rolled back merely by closing the screen/changing accounts; it keeps the original owner's ID and its acknowledgment is ignored by a stale screen. Cancellation closes owned HTTP transport and ignores late results, but cannot guarantee Google stops processing an already-received request.

The owner reports completing Android testing and approves the implementation/UI/UX. No per-scenario results, device model or screenshots were supplied; live-provider failure permutations, cross-device behavior, restart edge cases and accessibility remain follow-up checks. Automated validation: `dart format` completed on changed Dart files; all **305 Flutter tests pass**, including **63 new scanner tests**. `flutter analyze` reports the **same 12 pre-existing diagnostics** (5 warnings, 7 infos) as the AI Coach milestone, with no new scanner diagnostics or analyzer errors; its exit code remains 1. The warnings/infos are in the unchanged Profile, Progress, Settings and ProgressRepository files. The repository README now documents the implemented, owner-approved scanner and its limits. Android approval is recorded separately from automated coverage.

Publication validation was rerun on 5 November 2026: formatting of all 13 changed Dart files made no changes, all 305 tests passed, analysis matched the previous 12-diagnostic baseline, and the Android debug APK built successfully. The publication review found no exposed credentials or generated files among the 21 selected changes.

Automated coverage includes Gemini envelopes/estimates/error sanitization, unsupported images, timeouts, overlapping requests, retries, stale replies, account resets, local saving/retrieval, uncertain-write duplicate protection, picker cancellation, camera lifecycle and late capture, Android Back, keyboard/bottom insets, Nutrition integration, and small/landscape layouts at 200% text. Camera tests use a fake device boundary, service tests use HTTP fixtures, and persistence tests use SharedPreferences' test implementation; these are not live-device/provider verification.

The Android debug APK built successfully with the approved camera dependency. The owner subsequently tested and approved the implementation/UI/UX on their Android phone; this does not establish exhaustive provider/device verification.

The Android build creates a Kotlin compiler session directory under `android/.kotlin/`; the Android ignore file now excludes that generated output.


## Changed files

| Area | Files and purpose |
| --- | --- |
| Scanner screens | `lib/fitness/pages/calorie_scanner_page.dart` (entry/review/results), `lib/fitness/pages/food_camera_page.dart` (native capture/lifecycle) |
| Review state | `lib/fitness/controllers/food_scanner_controller.dart`, `lib/fitness/models/food_estimate.dart` |
| Gemini boundary | `lib/fitness/services/gemini_food_analyzer.dart`, `lib/fitness/services/ai_service.dart` (scanner delegation and compatibility wrapper only) |
| Device boundary | `lib/fitness/services/scanner_camera.dart` |
| Scanner components | `lib/fitness/widgets/food_estimate_editor.dart`, `lib/fitness/widgets/scanner_widgets.dart` |
| Nutrition integration | `lib/fitness/pages/meal_planner_page.dart` (AI estimate label only) |
| Dependency/build hygiene | `pubspec.yaml`, `pubspec.lock`, `android/.gitignore` |
| Tests | `test/scanner/gemini_food_analyzer_test.dart`, `test/scanner/food_scanner_controller_test.dart`, `test/scanner/food_scanner_page_test.dart` |
| Documentation | `README.md`, `docs/ui-ux/food-scanner-redesign.md`, `docs/ui-ux/food-scanner-repairs.md`, `docs/ui-ux/README.md`, `docs/ui-ux/screenshot-checklist.md` |

21 new/modified files including the repository README. The owner authorized committing/pushing this milestone and a normal merge into main after acceptable checks. No force-push, history rewrite, feature-branch deletion or further feature work is authorized.

## Android regression checklist

1. Install `build/app/outputs/flutter-apk/app-debug.apk` over the existing debug app (do not uninstall or clear storage if retaining local records). Alternatively run `/home/suboon/flutter/bin/flutter run -d <device-id>` from this workspace.
2. Sign in and open the existing Food/Calorie Scanner entry on Home. Compare the Midnight entry layout to Design 3; confirm no invented Recent Scans.
3. Take Photo: test permission allow and deny, native preview/frame alignment, switch on a supported multi-camera device, shutter, gallery shortcut, cancel/Back, then background/resume. Confirm no photo is analyzed before Analyze photo.
4. Choose from Gallery: cancel and reopen; try an unreadable/unsupported image, then a real JPEG/PNG/WebP food photo. File limit is 8 MB after picker processing.
5. Analyze explicitly. Check loading, duplicate-tap blocking, real food name/macros, optional identified items/portions/tip, AI Estimate explanation. Try airplane mode, then reconnect and Retry. Quota/provider errors depend on actual service conditions; no failures are simulated in the shipped UI.
6. Edit food name/quantity/nutrition. Try blank names, negative/fractional calories and invalid grams; check inline messages and keyboard scrolling. Apply should change the review only. Quantity changes should never silently alter nutrition.
7. Choose the meal category and Save to Nutrition once. Repeated taps must not create duplicates. Open View Nutrition and compare recorded values, totals and AI Estimate label; fully restart the app and confirm the meal remains. No photo/scan-history persistence is expected.
8. Test Android Back during capture/analysis, then a new scan. Sign out and use a second account: previous temporary scans should be gone and the saved meal must remain with its original owner. Check small screens, enlarged fonts, TalkBack, keyboard and system insets. Verify existing Home, workout, meal planner and chat flows still work.

Owner Android testing and implementation/UI/UX approval are recorded above. The checklist remains a regression guide; approval alone does not establish every listed edge case as individually verified. Stop after publishing and merging this milestone.
