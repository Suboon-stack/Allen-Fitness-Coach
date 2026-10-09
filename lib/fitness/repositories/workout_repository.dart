import 'package:allen/fitness/models/workout_model.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class WorkoutRepository {
  final LocalStorageService _local = LocalStorageService();
  final Uuid _uuid = const Uuid();

  Future<List<Workout>> getUserWorkouts(String userId, {int limit = 50}) async {
    try {
      final data = await _local.getWorkouts();
      final workouts = data
          .map((w) => Workout(
                id: w['id'] ?? '',
                userId: w['userId'] ?? userId,
                name: w['name'] ?? '',
                muscleGroup: w['muscleGroup'] ?? '',
                difficulty: w['difficulty'] ?? '',
                durationMinutes: w['durationMinutes'] ?? 0,
                exercises: (w['exercises'] as List?)
                        ?.map((e) => Exercise.fromMap(e))
                        .toList() ??
                    [],
                date: DateTime.parse(
                    w['date'] ?? DateTime.now().toIso8601String()),
                completed: w['completed'] ?? false,
                notes: w['notes'],
                createdAt: DateTime.parse(
                    w['createdAt'] ?? DateTime.now().toIso8601String()),
              ))
          .toList();

      workouts.sort((a, b) => b.date.compareTo(a.date));
      return workouts.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> createWorkout(Workout workout) async {
    final id = _uuid.v4();
    final workouts = await _local.getWorkouts();

    workouts.insert(0, {
      'id': id,
      'userId': workout.userId,
      'name': workout.name,
      'muscleGroup': workout.muscleGroup,
      'difficulty': workout.difficulty,
      'durationMinutes': workout.durationMinutes,
      'exercises': workout.exercises.map((e) => e.toMap()).toList(),
      'date': workout.date.toIso8601String(),
      'completed': workout.completed,
      'notes': workout.notes,
      'createdAt': workout.createdAt.toIso8601String(),
    });

    await _local.saveWorkouts(workouts);
    return id;
  }

  Future<void> updateWorkout(Workout workout) async {
    final workouts = await _local.getWorkouts();
    final index = workouts.indexWhere((w) => w['id'] == workout.id);
    if (index != -1) {
      workouts[index] = {
        'id': workout.id,
        'userId': workout.userId,
        'name': workout.name,
        'muscleGroup': workout.muscleGroup,
        'difficulty': workout.difficulty,
        'durationMinutes': workout.durationMinutes,
        'exercises': workout.exercises.map((e) => e.toMap()).toList(),
        'date': workout.date.toIso8601String(),
        'completed': workout.completed,
        'notes': workout.notes,
        'createdAt': workout.createdAt.toIso8601String(),
      };
      await _local.saveWorkouts(workouts);
    }
  }

  Future<void> deleteWorkout(String workoutId) async {
    final workouts = await _local.getWorkouts();
    workouts.removeWhere((w) => w['id'] == workoutId);
    await _local.saveWorkouts(workouts);
  }

  Future<void> markWorkoutComplete(String workoutId, bool completed) async {
    final workouts = await _local.getWorkouts();
    final index = workouts.indexWhere((w) => w['id'] == workoutId);
    if (index != -1) {
      workouts[index]['completed'] = completed;
      await _local.saveWorkouts(workouts);
    }
  }

  Future<int> getWorkoutCount(String userId) async {
    return await _local.getWorkoutCount();
  }

  Future<int> getTotalMinutes(String userId) async {
    final workouts = await getUserWorkouts(userId);
    int total = 0;
    for (final w in workouts.where((w) => w.completed)) {
      total += w.durationMinutes;
    }
    return total;
  }

  Future<int> getCurrentStreak(String userId) async {
    return await _local.getStreak();
  }

  Future<Map<String, int>> getMuscleGroupStats(String userId) async {
    final workouts = await getUserWorkouts(userId);
    final Map<String, int> stats = {};

    for (final workout in workouts.where((w) => w.completed)) {
      stats[workout.muscleGroup] = (stats[workout.muscleGroup] ?? 0) + 1;
    }

    return stats;
  }
}
