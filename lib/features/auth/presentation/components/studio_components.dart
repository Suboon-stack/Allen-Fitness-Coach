import 'package:allen/features/auth/presentation/theme/performance_theme.dart';
import 'package:flutter/material.dart';

class StudioWordmark extends StatelessWidget {
  const StudioWordmark({super.key, this.onDark = false});
  final bool onDark;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: onDark ? PerformanceTheme.lime : PerformanceTheme.cobalt,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.north_east_rounded,
                size: 22, color: onDark ? PerformanceTheme.ink : Colors.white)),
        const SizedBox(width: 10),
        Text('allen',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                color: onDark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface)),
      ]);
}

/// Decorative track: a visual metaphor for momentum, never a progress chart.
class MovementArtwork extends StatelessWidget {
  const MovementArtwork({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(painter: _MovementPainter(), size: Size.infinite),
      );
}

class _MovementPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 440, size.height / 280);
    for (var i = 0; i < 5; i++) {
      final offset = i * 18.0;
      final path = Path()
        ..moveTo(-50, 260 + offset)
        ..cubicTo(75, 260 + offset, 30, 45 + offset, 200, 45 + offset)
        ..cubicTo(340, 45 + offset, 240, 225 + offset, 490, 170 + offset);
      canvas.drawPath(
          path,
          Paint()
            ..color = i == 0 ? PerformanceTheme.lime : const Color(0xFF5E77F6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 0 ? 3 : 1.5);
    }
    canvas.drawCircle(
        const Offset(200, 45), 11, Paint()..color = PerformanceTheme.lime);
    canvas.drawCircle(
        const Offset(200, 45), 4, Paint()..color = PerformanceTheme.ink);
    canvas.drawCircle(
        const Offset(200, 45),
        23,
        Paint()
          ..color = PerformanceTheme.lime.withValues(alpha: .22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MovementPainter oldDelegate) => false;
}

class StudioAuthLayout extends StatelessWidget {
  const StudioAuthLayout(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.description,
      required this.child,
      this.onBack});
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) =>
      PerformanceScope(child: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Scaffold(
          body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final padding = constraints.maxWidth < 380 ? 20.0 : 32.0;
            final form = ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: StudioSpace.formWidth),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow,
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              letterSpacing: 1.5,
                              fontSize: 11)),
                      const SizedBox(height: 16),
                      Text(title, style: theme.textTheme.displaySmall),
                      const SizedBox(height: 12),
                      Text(description, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: StudioSpace.section),
                      child,
                    ]));
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                    child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: StudioSpace.contentWidth),
                  padding: EdgeInsets.all(padding),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                            height: 48,
                            child: Row(children: [
                              const StudioWordmark(),
                              const Spacer(),
                              if (onBack != null)
                                IconButton(
                                    tooltip: 'Back',
                                    onPressed: onBack,
                                    icon: const Icon(Icons.arrow_back_rounded)),
                            ])),
                        const SizedBox(height: 36),
                        if (wide)
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Expanded(child: _StudioSidePanel()),
                                const SizedBox(width: 64),
                                Expanded(
                                    child: Align(
                                        alignment: Alignment.centerRight,
                                        child: form)),
                              ])
                        else
                          Align(alignment: Alignment.topCenter, child: form),
                        const SizedBox(height: 24),
                      ]),
                )),
              ),
            );
          })),
        );
      }));
}

class _StudioSidePanel extends StatelessWidget {
  const _StudioSidePanel();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: PerformanceTheme.ink,
            borderRadius: BorderRadius.circular(32)),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BUILT AROUND YOU',
                  style: TextStyle(
                      color: PerformanceTheme.lime,
                      letterSpacing: 2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 32),
              Text('More intention.\nMore you.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5)),
              SizedBox(height: 20),
              Text(
                  'A space for your movement, your meals, and the questions along the way.',
                  style: TextStyle(
                      color: Color(0xFFB9C0D3), height: 1.6, fontSize: 16)),
              SizedBox(height: 24),
              SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: MovementArtwork()),
              SizedBox(height: 20),
              Text('MOVE / FUEL / EVOLVE',
                  style: TextStyle(
                      color: Colors.white,
                      letterSpacing: 2,
                      height: 1.5,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
      );
}

class StudioField extends StatefulWidget {
  const StudioField(
      {super.key,
      required this.controller,
      required this.label,
      required this.hint,
      this.validator,
      this.password = false,
      this.enabled = true,
      this.keyboardType,
      this.autofillHints,
      this.textInputAction = TextInputAction.next,
      this.onSubmitted,
      this.inputKey});
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final bool password;
  final bool enabled;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Key? inputKey;
  @override
  State<StudioField> createState() => _StudioFieldState();
}

class _StudioFieldState extends State<StudioField> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: TextFormField(
          key: widget.inputKey,
          controller: widget.controller,
          enabled: widget.enabled,
          validator: widget.validator,
          obscureText: widget.password && !_visible,
          enableSuggestions: !widget.password,
          autocorrect: false,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: widget.label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: widget.hint,
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: _visible ? 'Hide password' : 'Show password',
                    onPressed: widget.enabled
                        ? () => setState(() => _visible = !_visible)
                        : null,
                    icon: Icon(_visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                  )
                : null,
          ),
        ),
      );
}

class StudioButton extends StatelessWidget {
  const StudioButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.busy = false,
      this.busyLabel = 'Please wait…'});
  final String label;
  final String busyLabel;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
            onPressed: busy ? null : onPressed,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (busy) ...[
                const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12)
              ],
              Flexible(
                  child: Semantics(
                      liveRegion: true, child: Text(busy ? busyLabel : label))),
              if (!busy) ...[
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded, size: 20)
              ],
            ])),
      );
}

class StudioNotice extends StatelessWidget {
  const StudioNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded,
                color: colors.onErrorContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: TextStyle(
                        color: colors.onErrorContainer, height: 1.5))),
          ]),
        ));
  }
}

abstract final class StudioValidation {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email address.';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
      return 'Use an email like you@example.com.';
    }
    return null;
  }

  static String? password(String? value) =>
      value == null || value.isEmpty ? 'Enter your password.' : null;
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Choose a password.';
    return value.length < 6 ? 'Use at least 6 characters.' : null;
  }
}
