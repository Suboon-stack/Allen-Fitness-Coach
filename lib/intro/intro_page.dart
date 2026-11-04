import 'dart:math' as math;
import 'package:allen/features/auth/presentation/components/studio_components.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/intro/widgets/intro_motion_graphic.dart';
import 'package:flutter/material.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key, required this.onContinue, this.onSignIn});
  final VoidCallback onContinue;
  final VoidCallback? onSignIn;
  static const _headline = 'Fitness, on your terms.';
  static const _description =
      'Workouts, nutrition, and AI guidance. All in one place.';

  @override
  Widget build(BuildContext context) =>
      AppThemeScope(child: Builder(builder: (context) {
        final theme = Theme.of(context);
        final horizontal = MediaQuery.sizeOf(context).width < 380
            ? AppSpacing.page
            : AppSpacing.lg;
        return Scaffold(
          body: SafeArea(
              bottom: false,
              child: LayoutBuilder(builder: (context, constraints) {
                final width =
                    math.min(constraints.maxWidth, AppLayout.formWidth + 48) -
                        horizontal * 2;
                final scaler = MediaQuery.textScalerOf(context);
                final direction = Directionality.of(context);
                final copyHeight = _measure(
                        _headline,
                        theme.textTheme.headlineMedium,
                        width,
                        scaler,
                        direction) +
                    AppSpacing.sm +
                    _measure(_description, theme.textTheme.bodyLarge, width,
                        scaler, direction);
                // The footer has already been laid out by Scaffold. Only the remaining
                // body space participates here, so large text never crowds the actions.
                final reserve = 48 +
                    AppSpacing.lg +
                    AppSpacing.md +
                    AppSpacing.md +
                    AppSpacing.lg +
                    copyHeight;
                final minimum = constraints.maxHeight < 400 ? 64.0 : 96.0;
                final graphicHeight =
                    (constraints.maxHeight - reserve).clamp(minimum, 360.0);
                return SingleChildScrollView(
                    child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: AppLayout.formWidth + 48),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(horizontal, AppSpacing.lg,
                            horizontal, AppSpacing.md),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(
                                  height: 48,
                                  child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: StudioWordmark(label: 'Allen'))),
                              Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                      bottom: AppSpacing.lg),
                                  child: SizedBox(
                                      height: graphicHeight,
                                      child: const IntroMotionGraphic())),
                              Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(_headline,
                                        style: theme.textTheme.headlineMedium),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(_description,
                                        style: theme.textTheme.bodyLarge),
                                  ]),
                            ]),
                      ),
                    ),
                  ),
                ));
              })),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppLayout.formWidth + 48),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontal, 12, horizontal, AppSpacing.md),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StudioButton(
                              label: 'Get started', onPressed: onContinue),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('Already a member?'),
                                TextButton(
                                    onPressed: onSignIn ?? onContinue,
                                    child: const Text('Sign in')),
                              ]),
                        ]),
                  ),
                ),
              )),
        );
      }));

  double _measure(String text, TextStyle? style, double width,
      TextScaler scaler, TextDirection direction) {
    final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: scaler,
        textDirection: direction)
      ..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }
}
