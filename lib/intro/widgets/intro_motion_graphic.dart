import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A single decorative ribbon suggesting effort and forward movement.
/// Static by design: no ticker, repeating animation, or motion preference work.
class IntroMotionGraphic extends StatelessWidget {
  const IntroMotionGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IgnorePointer(
        child: ExcludeSemantics(
            child: RepaintBoundary(
      child: CustomPaint(
          size: Size.infinite,
          painter: _MomentumPainter(
            primary: colors.primary,
            highlight: colors.secondary,
          )),
    )));
  }
}

class _MomentumPainter extends CustomPainter {
  const _MomentumPainter({required this.primary, required this.highlight});
  final Color primary;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final ribbon = Path()
      ..moveTo(w * .10, h * .82)
      ..cubicTo(w * .27, h * .80, w * .26, h * .24, w * .46, h * .30)
      ..cubicTo(w * .64, h * .36, w * .57, h * .70, w * .76, h * .48)
      ..cubicTo(w * .84, h * .38, w * .88, h * .20, w * .92, h * .14);
    final edge = Path()
      ..moveTo(w * .10, h * .70)
      ..cubicTo(w * .27, h * .68, w * .28, h * .13, w * .48, h * .21)
      ..cubicTo(w * .66, h * .29, w * .61, h * .58, w * .78, h * .39);
    final width = (size.shortestSide * .11).clamp(14.0, 34.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
        ribbon,
        paint
          ..color = primary.withValues(alpha: .16)
          ..strokeWidth = width + 14);
    canvas.drawPath(
        ribbon,
        paint
          ..color = primary
          ..strokeWidth = width);
    canvas.drawPath(
        edge,
        paint
          ..color = highlight.withValues(alpha: .75)
          ..strokeWidth = 1.5);
    canvas.drawCircle(Offset(w * .92, h * .14), math.min(6, width * .18),
        Paint()..color = highlight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MomentumPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.highlight != highlight;
}
