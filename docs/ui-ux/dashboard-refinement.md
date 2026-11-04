# Compact Home review

Scope: Home, the required theme/shared components, dashboard tests, and documentation. The owner approved the compact Home UI after Android phone testing and authorized publishing this milestone to the existing redesign branch. The newer login refinement and its test changes remain outside this milestone.

The greeting and “Your day.” heading replace the oversized motivational introduction. A short mint Ask Allen panel has one coach action. Four actual activity values share a compact two-column surface instead of individual large cards: completed workouts, latest weight, workout streak, and today's logged water. At very large text sizes on narrow screens, the summary uses one column to preserve legibility. Missing weight is “Not logged”; zero counts represent empty stored records, not fabricated progress.

Navigation was explained before implementation: Home now has Material 3 bottom shortcuts for Home, Workouts, Nutrition, and Progress. They push the existing pages and use the normal back action to return, refreshing statistics on return. This is a Home-only shortcut bar, not a persistent tab shell; it does not alter feature pages or introduce duplicate navigation stacks. The drawer retains all existing routes, settings, About, profile, and sign out. The coach and food scanner remain available in the body. Repeated workout/nutrition/progress promotional cards are removed because those destinations are directly accessible at the bottom.

Daily motivation remains available in a compact collapsed disclosure, preserving the feature without dominating the page. Forest/mint themes are unchanged. No gradients, decorative illustrations, or additional large panels were added.

## Android review

Build/install the debug APK, sign in, and open Home. Compare the completed workout count, latest weight, and water with the corresponding feature pages; log water or weight and return to confirm refresh. Exercise all bottom shortcuts and Android Back, then use the drawer for the scanner, chat, profile, settings, and About. Expand Daily motivation and try pull-to-refresh. Check small screens, landscape, both brightness settings, enlarged text, and real-device TalkBack. The pre-existing workout completion bug can still affect whether records are marked complete; this stage does not repair that separate feature.

Separate root causes and data-source regression coverage are described in `dashboard-data-fixes.md`. The approved UI is ready for publication; remaining live-service and device-functionality checks are listed separately.

## Milestone validation

The selected publication snapshot is validated independently of unrelated local login edits. Command results are recorded below after execution. Owner review confirms the Home UI was tested on an Android phone; it does not establish that every Firebase/Gemini or fitness flow is verified.

Remaining manual checks include TalkBack and live Firebase/Gemini integration. The repository tests use SharedPreferences' in-memory test backend with deliberately conflicting records; no fixtures are added to production data. Older local-only runs included an additional login refinement test and are not used as the published snapshot's test count.

### Publication snapshot results

- Formatting passed on the five selected Dart files.
- `flutter test`: **33 passed** in a disposable copy of HEAD plus only the approved dashboard/documentation files. The uncommitted minimalist login refinement and its extra test were excluded. Sanitized configuration examples were used only in that temporary test copy.
- Scoped `flutter analyze`: **passed, no issues** for Home, its theme/components, main theme integration, and dashboard tests.
- Full `flutter analyze`: **14 pre-existing diagnostics** (5 warnings, 9 infos) in untouched fitness pages/repository; full-project exit remains nonzero. No unrelated lint fixes are included.
- Secret-pattern scan: no matches in the proposed source snapshot or the existing local branch commits being published. Actual local keys/configuration and generated files are excluded. This scan is not a security audit.
- Dependency lock unchanged; README local links verified.

The approved compact Home capture is not yet in the project. `docs/screenshots/approved/README.md` documents where to add the real Android screenshot; the older Home image is not represented as the approved design.
