import 'dart:math' as math;
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String trackerNumber(num value) =>
    value.isFinite ? NumberFormat('#,##0.##').format(value) : '—';

/// Shared nutrition/water ring. A missing goal draws only the background track,
/// never an indeterminate spinner or an invented percentage.
class TrackerProgress extends StatelessWidget {
  const TrackerProgress(
      {super.key,
      required this.value,
      required this.unit,
      required this.centerIcon,
      required this.semanticName,
      this.goal,
      this.goalLabel = 'Daily goal',
      this.noGoalLabel = 'No goal configured.'});
  final double value;
  final String unit;
  final Widget centerIcon;
  final String semanticName;
  final double? goal;
  final String goalLabel;
  final String noGoalLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validValue = value.isFinite && value >= 0;
    final validGoal = goal != null && goal!.isFinite && goal! > 0;
    final fraction = validValue && validGoal ? value / goal! : 0.0;
    final ratio = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 1.0;
    final percent = validValue && validGoal && (fraction * 100).isFinite
        ? '${trackerNumber(fraction * 100)}%'
        : null;
    final goalText =
        validGoal ? '$goalLabel · ${trackerNumber(goal!)} $unit' : noGoalLabel;
    final number = validValue ? trackerNumber(value) : '—';
    final media = MediaQuery.of(context);
    final largeText = media.textScaler.scale(32) > 48 || number.length > 7;
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    final valueWidget = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(number,
          style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
      Text('$unit logged today',
          style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
    ]);
    return Semantics(
        label: validValue
            ? '$semanticName, $number $unit logged today. $goalText${percent == null ? '' : '. $percent of goal'}'
            : '$semanticName total unavailable.',
        liveRegion: true,
        child: ExcludeSemantics(
            child: LayoutBuilder(builder: (context, constraints) {
          final diameter = math.min(
              constraints.maxWidth, media.size.height < 500 ? 168.0 : 224.0);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox.square(
                dimension: diameter,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: ratio),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              builder: (context, progress, _) =>
                                  CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 8,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: theme
                                          .colorScheme.surfaceContainerHigh,
                                      color: theme.colorScheme.primary)))),
                  Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        IconTheme(
                            data: IconThemeData(
                                size: 28, color: theme.colorScheme.secondary),
                            child: SizedBox.square(
                                dimension: 28, child: centerIcon)),
                        if (!largeText) ...[
                          const SizedBox(height: AppSpacing.sm),
                          valueWidget
                        ],
                      ])),
                ])),
            if (largeText) ...[
              const SizedBox(height: AppSpacing.md),
              valueWidget
            ],
            const SizedBox(height: AppSpacing.md),
            Text(goalText,
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            if (percent != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('$percent of goal',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.secondary),
                  textAlign: TextAlign.center)
            ],
          ]);
        })));
  }
}

/// Original monochrome fruit outline (not a company logo or downloaded asset).
class NutritionAppleIcon extends StatelessWidget {
  const NutritionAppleIcon({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _ApplePainter(IconTheme.of(context).color ??
          Theme.of(context).colorScheme.secondary));
}

class _ApplePainter extends CustomPainter {
  const _ApplePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fruit = Path()
      ..moveTo(w * .50, h * .32)
      ..cubicTo(w * .24, h * .13, w * .08, h * .37, w * .20, h * .67)
      ..cubicTo(w * .28, h * .92, w * .40, h * .91, w * .50, h * .85)
      ..cubicTo(w * .61, h * .92, w * .73, h * .92, w * .82, h * .67)
      ..cubicTo(w * .96, h * .37, w * .76, h * .13, w * .50, h * .32);
    final stem = Path()
      ..moveTo(w * .50, h * .31)
      ..quadraticBezierTo(w * .46, h * .18, w * .51, h * .08);
    final leaf = Path()
      ..moveTo(w * .56, h * .18)
      ..quadraticBezierTo(w * .63, h * .03, w * .79, h * .08)
      ..quadraticBezierTo(w * .71, h * .22, w * .56, h * .18);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(fruit, paint);
    canvas.drawPath(stem, paint);
    canvas.drawPath(leaf, paint);
  }

  @override
  bool shouldRepaint(_ApplePainter oldDelegate) => oldDelegate.color != color;
}
