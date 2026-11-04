import 'package:allen/fitness/models/workout_model.dart';

class WorkoutGenerationException implements Exception {
  const WorkoutGenerationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WorkoutExerciseDetail {
  const WorkoutExerciseDetail({required this.exercise, this.instructions});
  final Exercise exercise;
  final String? instructions;
}

class ParsedWorkoutPlan {
  const ParsedWorkoutPlan({required this.source, required this.details});
  final String source;
  final List<WorkoutExerciseDetail> details;
  List<Exercise> get exercises =>
      details.map((detail) => detail.exercise).toList();
}

/// Validates the existing pipe-delimited contract without inventing defaults.
/// Optional rest/instruction cells are retained verbatim in the existing notes.
abstract final class WorkoutPlanParser {
  static ParsedWorkoutPlan parse(String source) {
    final details = <WorkoutExerciseDetail>[];
    for (final raw in source.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('```')) continue;
      var parts = line.split('|').map((part) => part.trim()).toList();
      if (parts.first.isEmpty) parts.removeAt(0);
      if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
      if (parts.isEmpty) continue;
      if (parts.every((part) => RegExp(r'^[:\-\s]+$').hasMatch(part))) continue;
      final heading =
          parts.first.toLowerCase().replaceAll(RegExp(r'[_*]'), ' ');
      if (['exercise', 'exercise name', 'name'].contains(heading) &&
          parts.length >= 3 &&
          parts[1].toLowerCase().contains('sets')) {
        continue;
      }
      if (parts.length < 3 || parts.length > 5) {
        throw const WorkoutGenerationException(
            'Allen returned an incomplete workout. Please try generating it again.');
      }
      final prescription =
          RegExp(r'^(\d+)\s*[x×X]\s*(\d+)(?:\s*reps?)?$', caseSensitive: false)
              .firstMatch(parts[1]);
      if (prescription == null) {
        throw const WorkoutGenerationException(
            'This plan contains an unsupported set or rep format. Please try again for a repetition-based workout.');
      }
      final sets = int.tryParse(prescription.group(1)!);
      final reps = int.tryParse(prescription.group(2)!);
      final name = parts[0]
          .replaceFirst(RegExp(r'^(?:\d+[.)]\s*|[-*]\s+)'), '')
          .replaceAll('**', '')
          .trim();
      final muscle = parts[2].replaceAll('**', '').trim();
      if (name.isEmpty ||
          muscle.isEmpty ||
          sets == null ||
          reps == null ||
          sets <= 0 ||
          reps <= 0) {
        throw const WorkoutGenerationException(
            'The workout is missing a valid exercise, muscle group, or positive set/rep count. Please try again.');
      }
      final extra = parts.skip(3).where((part) => part.isNotEmpty).join(' · ');
      details.add(WorkoutExerciseDetail(
        exercise: Exercise(name: name, sets: sets, reps: reps, muscle: muscle),
        instructions: extra.isEmpty ? null : extra,
      ));
    }
    if (details.isEmpty) {
      throw const WorkoutGenerationException(
          'Allen did not return any exercises. Please try again.');
    }
    return ParsedWorkoutPlan(
        source: source, details: List.unmodifiable(details));
  }

  /// Legacy records remain readable. Notes supply optional details only when
  /// they describe exactly the stored exercises, not unrelated user notes.
  static ParsedWorkoutPlan? restoredPlan(Workout workout) {
    final notes = workout.notes;
    if (notes != null) {
      try {
        final parsed = parse(notes);
        if (parsed.exercises.length == workout.exercises.length) {
          var matches = true;
          for (var i = 0; i < workout.exercises.length; i++) {
            final stored = workout.exercises[i];
            final restored = parsed.exercises[i];
            if (stored.name != restored.name ||
                stored.sets != restored.sets ||
                stored.reps != restored.reps ||
                stored.muscle != restored.muscle) {
              matches = false;
            }
          }
          if (matches) return parsed;
        }
      } on WorkoutGenerationException {
        // Existing free-text notes are not a generated exercise prescription.
      }
    }
    return null;
  }

  static List<WorkoutExerciseDetail> detailsFor(Workout workout) =>
      restoredPlan(workout)?.details ??
      workout.exercises
          .map((exercise) => WorkoutExerciseDetail(exercise: exercise))
          .toList();
}
