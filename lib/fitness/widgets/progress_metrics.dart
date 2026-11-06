import 'package:flutter/material.dart';
import '../models/progress_tracking_data.dart';

class ProgressMetrics extends StatelessWidget {
  const ProgressMetrics({super.key, required this.data});
  final ProgressViewData data;
  @override
  Widget build(BuildContext context) {
    final nutrition = data.todayNutrition, goals = data.snapshot.goals;
    final values = <({
      String label,
      String value,
      String detail,
      IconData icon,
      double? ratio
    })>[
      (
        label: 'Workouts',
        value: data.snapshot.workouts == null ? '—' : '${data.workouts.length}',
        detail: data.snapshot.workouts == null
            ? 'History couldn’t load'
            : 'Completed · ${data.period.label} · no saved target',
        icon: Icons.fitness_center,
        ratio: null
      ),
      (
        label: 'Nutrition',
        value: nutrition == null ? '—' : '${nutrition.calories} kcal',
        detail: data.snapshot.meals == null
            ? 'Meals couldn’t load'
            : nutrition == null
                ? 'No meals logged today'
                : goals?.calories == null
                    ? 'Today · no saved calorie target'
                    : 'Today · target ${goals!.calories!.toStringAsFixed(0)} kcal',
        icon: Icons.restaurant_outlined,
        ratio: nutrition != null && goals?.calories != null
            ? nutrition.calories / goals!.calories!
            : null
      ),
      (
        label: 'Water',
        value: '—',
        detail: 'Account ownership not supported yet',
        icon: Icons.water_drop_outlined,
        ratio: null
      ),
      if (data.showProtein)
        (
          label: 'Protein',
          value: '${nutrition!.protein.toStringAsFixed(1)} g',
          detail: 'Today · target ${goals!.protein!.toStringAsFixed(0)} g',
          icon: Icons.grain_outlined,
          ratio: nutrition.protein / goals.protein!
        ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14);
      final columns = constraints.maxWidth >= 340 && scale <= 17
          ? values.length
          : constraints.maxWidth >= 290 && scale <= 24
              ? 2
              : 1;
      final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
      return Wrap(spacing: 16, runSpacing: 20, children: [
        for (final metric in values)
          SizedBox(
              width: width,
              child: Column(children: [
                if (metric.ratio != null)
                  Semantics(
                      label:
                          '${metric.label}: ${!metric.ratio!.isFinite || metric.ratio! > 10 ? 'more than 1,000' : (metric.ratio! * 100).round()} percent of saved target',
                      child: SizedBox.square(
                          dimension: 70,
                          child: Stack(alignment: Alignment.center, children: [
                            SizedBox.expand(
                                child: CircularProgressIndicator(
                                    value: metric.ratio!.clamp(0, 1),
                                    strokeWidth: 6,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    strokeCap: StrokeCap.round)),
                            Icon(metric.icon,
                                color: Theme.of(context).colorScheme.secondary),
                          ])))
                else
                  SizedBox.square(
                      dimension: 70,
                      child: Icon(metric.icon,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 28)),
                const SizedBox(height: 10),
                Text(metric.value,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(metric.label,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(metric.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
              ]))
      ]);
    });
  }
}
