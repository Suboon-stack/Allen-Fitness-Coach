import 'package:allen/fitness/models/workout_model.dart';
import 'package:allen/fitness/services/workout_plan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Parses markdown tables, multiplication symbols, and optional supplied instructions',
      () {
    final plan = WorkoutPlanParser.parse('''```text
| Exercise | Sets x Reps | Muscle | Instructions |
| --- | --- | --- | --- |
| **Push Ups** | 3 × 12 | Chest | Rest 60 seconds |
| 2. Squats | 4 X 10 reps | Legs | Keep your heels down |
```''');
    expect(plan.exercises.map((e) => e.name), ['Push Ups', 'Squats']);
    expect(plan.exercises.first.sets, 3);
    expect(plan.exercises.last.reps, 10);
    expect(plan.details.first.instructions, 'Rest 60 seconds');
  });
  for (final source in [
    '',
    'Error: unavailable',
    'Push Ups | 3 | Chest',
    'Plank | 3 x 60s | Core',
    'Squats | 3 x 8-12 | Legs',
    'Push Ups | 0 x 10 | Chest',
    '| 3 x 10 | Chest',
    'Push Ups | 3 x 10 | Chest\nBroken exercise | missing'
  ]) {
    test(
        'Rejects malformed/incomplete response without invented defaults: $source',
        () {
      expect(() => WorkoutPlanParser.parse(source),
          throwsA(isA<WorkoutGenerationException>()));
    });
  }
  test(
      'Optional details survive in the existing notes field; legacy exercises remain readable',
      () {
    const source = 'Push Ups | 3 x 12 | Chest | Rest 60s';
    final plan = WorkoutPlanParser.parse(source);
    final now = DateTime.now();
    final workout = Workout(
        id: 'saved',
        userId: 'member',
        name: 'Chest workout',
        muscleGroup: 'Chest',
        difficulty: 'Beginner',
        durationMinutes: 20,
        exercises: plan.exercises,
        date: now,
        createdAt: now,
        notes: source);
    expect(
        WorkoutPlanParser.detailsFor(workout).single.instructions, 'Rest 60s');
    final legacy = Workout(
        id: 'legacy',
        userId: 'member',
        name: 'Legacy workout',
        muscleGroup: 'Chest',
        difficulty: 'Beginner',
        durationMinutes: 20,
        exercises: [
          Exercise(name: 'Bench Press', sets: 4, reps: 8, muscle: 'Chest')
        ],
        date: now,
        createdAt: now,
        notes: 'An existing personal note.');
    expect(WorkoutPlanParser.detailsFor(legacy).single.exercise.reps, 8);
    expect(WorkoutPlanParser.restoredPlan(legacy), isNull);
  });
}
