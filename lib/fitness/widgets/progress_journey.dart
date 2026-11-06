import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressJourney extends StatelessWidget {
  const ProgressJourney(
      {super.key, required this.summary, required this.period});
  final String summary, period;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: Container(
            decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(AppRadii.panel)),
            child: LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21;
              final text = Padding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Journey',
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Text(summary,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: theme.colorScheme.secondary)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                            '$period · Every record helps you see your journey.',
                            style: theme.textTheme.bodySmall),
                      ]));
              final art = ExcludeSemantics(
                  child: CustomPaint(
                      size: const Size(160, 130),
                      painter: _MountainPainter(
                          primary: theme.colorScheme.primary,
                          light: theme.colorScheme.secondary,
                          base: theme.colorScheme.surfaceContainerHigh)));
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [text, SizedBox(height: 100, child: art)])
                  : Row(children: [
                      Expanded(flex: 3, child: text),
                      Expanded(flex: 2, child: art)
                    ]);
            })));
  }
}

/// Original layered geometry. No raster asset, dependency or decorative motion.
class _MountainPainter extends CustomPainter {
  const _MountainPainter(
      {required this.primary, required this.light, required this.base});
  final Color primary, light, base;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Path ridge(List<Offset> points) {
      final p = Path()..moveTo(0, h);
      for (final v in points) {
        p.lineTo(v.dx * w, v.dy * h);
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    canvas.drawPath(
        ridge([
          const Offset(0, .78),
          const Offset(.25, .38),
          const Offset(.49, .65),
          const Offset(.8, .3),
          const Offset(1, .55)
        ]),
        Paint()..color = base);
    canvas.drawPath(
        ridge([
          const Offset(.08, 1),
          const Offset(.34, .59),
          const Offset(.47, .74),
          const Offset(.69, .18),
          const Offset(1, .93)
        ]),
        Paint()..color = primary);
    canvas.drawPath(
        ridge([
          const Offset(.69, .18),
          const Offset(.77, .6),
          const Offset(.85, .57),
          const Offset(1, .93)
        ]),
        Paint()..color = base);
    canvas.drawPath(
        Path()
          ..moveTo(w * .54, h * .54)
          ..lineTo(w * .69, h * .18)
          ..lineTo(w * .82, h * .53)
          ..lineTo(w * .72, h * .42)
          ..lineTo(w * .68, h * .49)
          ..lineTo(w * .63, h * .44)
          ..close(),
        Paint()..color = light);
    final pole = Paint()
      ..color = light
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * .69, h * .18), Offset(w * .69, h * .02), pole);
    canvas.drawPath(
        Path()
          ..moveTo(w * .69, h * .02)
          ..lineTo(w * .84, h * .04)
          ..lineTo(w * .79, h * .1)
          ..lineTo(w * .69, h * .09)
          ..close(),
        Paint()..color = light);
  }

  @override
  bool shouldRepaint(_MountainPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.light != light ||
      oldDelegate.base != base;
}
