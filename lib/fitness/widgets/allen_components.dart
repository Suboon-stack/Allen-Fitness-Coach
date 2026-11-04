import 'package:flutter/material.dart';

/// Shared spacing tokens for the redesigned presentation layer.
abstract final class AllenSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double maxContentWidth = 1040;
}

class AllenCard extends StatelessWidget {
  const AllenCard(
      {super.key,
      required this.child,
      this.onTap,
      this.padding = const EdgeInsets.all(AllenSpacing.lg)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child:
          InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class AllenButton extends StatelessWidget {
  const AllenButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon = Icons.arrow_forward_rounded,
      this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox.square(
                dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 20),
        label: Text(loading ? 'Please wait…' : label),
      );
}

class AllenSectionTitle extends StatelessWidget {
  const AllenSectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: AllenSpacing.xs),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      );
}

class AllenMetric {
  const AllenMetric({required this.label, required this.value});
  final String label;
  final String value;
}

/// A single compact summary surface, rather than one large card per metric.
class AllenMetricGrid extends StatelessWidget {
  const AllenMetricGrid({super.key, required this.metrics});
  final List<AllenMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant)),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 &&
                MediaQuery.textScalerOf(context).scale(12) > 22
            ? 1
            : 2;
        return Wrap(children: [
          for (final metric in metrics)
            SizedBox(
              width: constraints.maxWidth / columns,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Semantics(
                      label: '${metric.label}: ${metric.value}',
                      excludeSemantics: true,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(metric.value,
                                style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 24, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(metric.label,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontSize: 12)),
                          ]))),
            ),
        ]);
      }),
    );
  }
}
