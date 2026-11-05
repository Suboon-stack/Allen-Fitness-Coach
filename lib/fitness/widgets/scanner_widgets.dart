import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScannerFrame extends StatelessWidget {
  const ScannerFrame({super.key, this.child, this.color});
  final Widget? child;
  final Color? color;
  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter:
            _FramePainter(color ?? Theme.of(context).colorScheme.secondary),
        child: child,
      );
}

class _FramePainter extends CustomPainter {
  const _FramePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final length = size.shortestSide * .17;
    for (final offset in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height)
    ]) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.scale(offset.dx == 0 ? 1 : -1, offset.dy == 0 ? 1 : -1);
      canvas.drawPath(
          Path()
            ..moveTo(2, length)
            ..lineTo(2, 15)
            ..quadraticBezierTo(2, 2, 15, 2)
            ..lineTo(length, 2),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate.color != color;
}

class ScannerPhoto extends StatelessWidget {
  const ScannerPhoto({super.key, required this.file, this.fit = BoxFit.cover});
  final File file;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: Image.file(file,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const Center(
              child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                      'Photo preview unavailable. Choose another image.')))));
}

class ScannerFeedback extends StatelessWidget {
  const ScannerFeedback(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(message,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (onRetry != null)
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: onRetry, child: const Text('Retry'))),
          ])));
}

String scanNumber(num value) => value is int || value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
