import 'dart:convert';
import 'package:allen/fitness/models/workout_model.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Workout sampleWorkout(String id, {DateTime? date}) {
  final day = date ?? DateTime.now();
  return Workout(
      id: id,
      userId: 'member',
      name: 'Chest workout',
      muscleGroup: 'Chest',
      difficulty: 'Intermediate',
      durationMinutes: 45,
      exercises: [
        Exercise(name: 'Push Ups', sets: 3, reps: 12, muscle: 'Chest')
      ],
      date: day,
      createdAt: day,
      notes: 'Push Ups | 3 x 12 | Chest | Rest 60s');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('The same draft UUID saves once, including concurrent retries',
      () async {
    final workout = sampleWorkout('draft-id');
    final ids = await Future.wait([
      WorkoutRepository().createWorkout(workout),
      WorkoutRepository().createWorkout(workout)
    ]);
    expect(ids, ['draft-id', 'draft-id']);
    final raw = await LocalStorageService().getWorkouts();
    expect(raw, hasLength(1));
    expect(raw.single.keys.toSet(), {
      'id',
      'userId',
      'name',
      'muscleGroup',
      'difficulty',
      'durationMinutes',
      'exercises',
      'date',
      'completed',
      'notes',
      'createdAt'
    });
    expect(raw.single['notes'], workout.notes);
  });
  test('Empty IDs still get a generated UUID for existing callers', () async {
    final id = await WorkoutRepository().createWorkout(sampleWorkout(''));
    expect(id, isNotEmpty);
    expect((await WorkoutRepository().getUserWorkouts('member')).single.id, id);
  });
  test(
      'Completes only the saved UUID; duplicate completion does not change dates or add records',
      () async {
    final repo = WorkoutRepository();
    final old = DateTime.now().subtract(const Duration(days: 21));
    await repo.createWorkout(sampleWorkout('first', date: old));
    await repo.createWorkout(sampleWorkout('second', date: old));
    await repo.markWorkoutComplete('second', true);
    final beforeRetry =
        (await SharedPreferences.getInstance()).getString('workouts');
    await repo.markWorkoutComplete('second', true);
    expect((await SharedPreferences.getInstance()).getString('workouts'),
        beforeRetry);
    final history = await repo.getUserWorkouts('member');
    expect(history.singleWhere((w) => w.id == 'first').completed, isFalse);
    final completed = history.singleWhere((w) => w.id == 'second');
    expect(completed.completed, isTrue);
    expect(completed.createdAt, old);
    final today = DateTime.now();
    expect([completed.date.year, completed.date.month, completed.date.day],
        [today.year, today.month, today.day]);
    expect(await repo.getWorkoutCount('member'), 1);
    expect(await repo.getCurrentStreak('member'), 1);
    expect(await repo.getTotalMinutes('member'), 45);
    expect(
        (await ProgressRepository()
            .getProgressStats('member'))['weeklyWorkouts'],
        1);
  });
  test(
      'Completion survives clearing the preferences cache and constructing a new repository',
      () async {
    await WorkoutRepository().createWorkout(sampleWorkout('persisted'));
    await WorkoutRepository().markWorkoutComplete('persisted', true);
    final encoded =
        (await SharedPreferences.getInstance()).getString('workouts')!;
    SharedPreferences.setMockInitialValues({'workouts': encoded});
    final restored =
        (await WorkoutRepository().getUserWorkouts('member')).single;
    expect(restored.id, 'persisted');
    expect(restored.completed, isTrue);
    expect(restored.notes, contains('Rest 60s'));
  });
  test(
      'Concurrent writes through separate repositories retain both completed records',
      () async {
    await Future.wait([
      WorkoutRepository().createWorkout(sampleWorkout('a')),
      WorkoutRepository().createWorkout(sampleWorkout('b')),
    ]);
    await Future.wait([
      WorkoutRepository().markWorkoutComplete('a', true),
      WorkoutRepository().markWorkoutComplete('b', true),
    ]);
    final history = await WorkoutRepository().getUserWorkouts('member');
    expect(history, hasLength(2));
    expect(history.every((w) => w.completed), isTrue);
  });
  test('Missing UUID failure is explicit and does not poison subsequent writes',
      () async {
    final repo = WorkoutRepository();
    await expectLater(repo.markWorkoutComplete('Push Ups', true),
        throwsA(isA<WorkoutStorageException>()));
    await repo.createWorkout(sampleWorkout('valid'));
    await repo.markWorkoutComplete('valid', true);
    expect(await repo.getWorkoutCount('member'), 1);
  });
  test('Unreadable history is not silently replaced or deleted', () async {
    SharedPreferences.setMockInitialValues({'workouts': '{broken-json'});
    await expectLater(WorkoutRepository().getUserWorkouts('member'),
        throwsA(isA<WorkoutStorageException>()));
    expect((await SharedPreferences.getInstance()).getString('workouts'),
        '{broken-json');
  });
  test(
      'Malformed exercise rows fail history loading without rewriting legacy data',
      () async {
    final raw = jsonEncode([
      {
        'id': 'legacy',
        'date': DateTime.now().toIso8601String(),
        'exercises': 'not-a-list'
      }
    ]);
    SharedPreferences.setMockInitialValues({'workouts': raw});
    await expectLater(WorkoutRepository().getUserWorkouts('member'),
        throwsA(isA<WorkoutStorageException>()));
    expect((await SharedPreferences.getInstance()).getString('workouts'), raw);
  });
  test('Legacy personal notes and extra record fields survive completion',
      () async {
    final now = DateTime.now().toIso8601String();
    await LocalStorageService().saveWorkouts([
      {
        'id': 'legacy',
        'userId': 'member',
        'date': now,
        'createdAt': now,
        'completed': false,
        'notes': 'My note',
        'extraLegacyField': 'preserve me'
      }
    ]);
    await WorkoutRepository().markWorkoutComplete('legacy', true);
    final raw = (await LocalStorageService().getWorkouts()).single;
    expect(raw['extraLegacyField'], 'preserve me');
    expect(raw['notes'], 'My note');
    expect(raw['createdAt'], now);
  });
}
