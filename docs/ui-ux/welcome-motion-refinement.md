# Welcome screen — abstract motion refinement

Scope: only IntroPage, its new decorative painter, welcome tests, and this review note. Existing work is preserved. The owner has since approved the UI on Android and authorized the redesign-branch milestone commit and push.

## Design

The headline “Fitness, on your terms.” and description “Workouts, nutrition, and AI guidance. All in one place.” are unchanged. One blue ribbon moves visually from lower left to upper right, with a restrained edge highlight and a small endpoint. It suggests movement without depicting fabricated activity or progress data. Its colors come directly from the existing Midnight theme.

The graphic uses CustomPainter and has no asset downloads, dependencies, gradients, shadows, feature icons, promotional cards, or extra slogans. It is static rather than animated, so reduced-motion settings are respected without a repeating ticker. Decorative content is excluded from semantics and ignores pointer events.

## Layout and accessibility

The wordmark stays near the top; artwork and copy occupy the body; Get Started and Sign In remain in a flat bottom safe-area action region. The body can scroll independently for large text or short screens. Artwork height adapts to remaining body space using the actual scaled headline/description metrics. The same constrained width aligns copy and buttons; normal typography and shared spacing tokens are retained.

Welcome-only callbacks and the optional sign-in fallback are preserved. Auth gate, login/registration/reset, Home, Workout Planner, shared components, and business services are unchanged during this refinement.

## Review checklist

- Check the flow and proportions on a small phone, a tall phone, and in landscape.
- Confirm headline/description have not changed and that there is exactly one decorative illustration.
- Check that both actions remain easily reachable with 200% text and Android gesture/navigation insets.
- Verify Get Started opens the existing registration flow and Sign In opens login.
- Check TalkBack skips the decorative ribbon and reads the normal content/actions in order.
- Capture an actual Android screenshot as `docs/ui-ux/screenshots/welcome-motion-midnight.png` after review. No new screenshot or device approval is claimed here.

## Validation

Fourteen targeted tests cover five viewport sizes at default/200% text, safe areas, callbacks/fallback, pointer/semantic exclusion, and reduced-motion/no-animation behavior. Tests do not use Firebase or Gemini.

- `dart format`: passed; final check reports no changes across the three Welcome Dart files.
- Scoped `flutter analyze`: passed with no issues for the Welcome screen, painter, and tests.
- Full `flutter analyze`: still reports 14 existing diagnostics in unchanged feature/service files (five warnings and nine informational diagnostics). No new Welcome diagnostics.
- Full `flutter test`: all 108 tests passed, including the 14 Welcome tests.
- Android debug APK: built successfully at `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed. Existing Dart source outside IntroPage was compared with a pre-edit hash snapshot and is unchanged by this refinement.

The owner has since approved the latest UI on an Android phone, including the Welcome refinement and capitalized “Allen” wordmark. TalkBack and actual screenshot capture remain pending. The results above describe implementation-stage checks; current pre-push checks are recorded in the [milestone review](approved-midnight-milestone.md).

Changed/new files: `lib/intro/intro_page.dart`, `lib/intro/widgets/intro_motion_graphic.dart`, `test/intro/intro_page_test.dart`, and `docs/ui-ux/welcome-motion-refinement.md`.
