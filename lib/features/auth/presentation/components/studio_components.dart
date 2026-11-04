import 'package:allen/features/auth/presentation/theme/performance_theme.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:flutter/material.dart';

class StudioWordmark extends StatelessWidget {
  const StudioWordmark({super.key, this.label = 'allen'});
  final String label;
  @override
  Widget build(BuildContext context) => Text(
        label,
        textScaler: TextScaler.noScaling,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: AppType.wordmark,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7),
      );
}

/// A single, keyboard-safe form column shared by registration, reset and intro.
class StudioAuthLayout extends StatelessWidget {
  const StudioAuthLayout(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.description,
      required this.child,
      this.onBack});
  // Kept for presentation-call compatibility; introductory taglines are no
  // longer rendered alongside the one primary heading.
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) =>
      PerformanceScope(child: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Scaffold(body:
            SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxHeight < 600;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppLayout.formWidth + 48),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth < 380
                            ? AppSpacing.page
                            : AppSpacing.lg,
                        vertical: AppSpacing.lg),
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
                                      icon:
                                          const Icon(Icons.arrow_back_rounded)),
                              ])),
                          SizedBox(height: compact ? AppSpacing.xl : 56),
                          Text(title, style: theme.textTheme.headlineMedium),
                          const SizedBox(height: AppSpacing.sm),
                          Text(description, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: AppSpacing.xl),
                          child,
                        ]),
                  ),
                )),
          );
        })));
      }));
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
              borderRadius: BorderRadius.circular(AppRadii.panel)),
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
