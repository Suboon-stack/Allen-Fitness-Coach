import 'package:allen/fitness/services/workout_plan_parser.dart';
import 'package:flutter/material.dart';

/// Compact rows share dividers, not a separate large card for every exercise.
class WorkoutExerciseList extends StatelessWidget {
  const WorkoutExerciseList({super.key, required this.details});
  final List<WorkoutExerciseDetail> details;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < details.length; i++) ...[
        if (i > 0) const Divider(height: 1),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. ${details[i].exercise.name}',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                  '${details[i].exercise.sets} sets × ${details[i].exercise.reps} reps · ${details[i].exercise.muscle}',
                  style: theme.textTheme.bodyMedium),
              if (details[i].exercise.weight != null)
                Text('${details[i].exercise.weight} kg',
                    style: theme.textTheme.bodyMedium),
              if (details[i].instructions != null) ...[
                const SizedBox(height: 6),
                Text(details[i].instructions!,
                    style: theme.textTheme.bodyMedium),
              ],
            ])),
      ],
    ]);
  }
}

class WorkoutFeedback extends StatelessWidget {
  const WorkoutFeedback(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message,
                style: TextStyle(color: colors.onErrorContainer, height: 1.5)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Try again')),
          ]),
        ));
  }
}
