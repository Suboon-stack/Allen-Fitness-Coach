import 'package:allen/fitness/models/workout_model.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class WorkoutStorageException implements Exception {
  const WorkoutStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WorkoutRepository {
  final LocalStorageService _local = LocalStorageService();
  final Uuid _uuid = const Uuid();

  // SharedPreferences stores the whole list. Serialize mutations across repo
  // instances so concurrent save/complete/delete actions cannot lose records.
  static Future<void>? _writeTail;
  static Future<T> _write<T>(Future<T> Function() action) {
    final predecessor = _writeTail;
    final result = predecessor == null
        ? Future<T>.sync(action)
        : predecessor.then((_) => action());
    final tail =
        result.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    _writeTail = tail;
    // Finish cleanup before returning to callers. An idle queue must not retain
    // a completed Future (or its zone) indefinitely after the last mutation.
    return result.whenComplete(() {
      if (identical(_writeTail, tail)) _writeTail = null;
    });
  }

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
                        ?.map((e) =>
                            Exercise.fromMap(Map<String, dynamic>.from(e)))
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
    } catch (_) {
      // Do not misrepresent unreadable stored data as an empty history.
      throw const WorkoutStorageException(
          'Saved workouts couldn’t be read. Please retry. Your stored records have not been deleted.');
    }
  }

  Future<String> createWorkout(Workout workout) => _write(() async {
        final id = workout.id.isEmpty ? _uuid.v4() : workout.id;
        final workouts = await _local.getWorkouts();
        final existing = workouts.where((w) => w['id'] == id);
        if (existing.isNotEmpty) {
          if (existing.first['userId'] != workout.userId) {
            throw const WorkoutStorageException(
                'This workout identifier is already in use. Please generate a new plan.');
          }
          return id; // Retrying the same draft must not create a second record.
        }
        workouts.insert(0, _record(workout, id));
        await _local.saveWorkouts(workouts);
        return id;
      });

  Future<void> updateWorkout(Workout workout) => _write(() async {
        final workouts = await _local.getWorkouts();
        final index = workouts.indexWhere((w) => w['id'] == workout.id);
        if (index == -1) {
          throw const WorkoutStorageException(
              'This workout no longer exists. Refresh your saved workouts.');
        }
        workouts[index] = _record(workout, workout.id);
        await _local.saveWorkouts(workouts);
      });

  Map<String, dynamic> _record(Workout workout, String id) => {
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
      };

  Future<void> deleteWorkout(String workoutId) => _write(() async {
        final workouts = await _local.getWorkouts();
        final index = workouts.indexWhere((w) => w['id'] == workoutId);
        if (index == -1) {
          throw const WorkoutStorageException(
              'This workout no longer exists. Refresh your saved workouts.');
        }
        workouts.removeAt(index);
        await _local.saveWorkouts(workouts);
      });

  Future<void> markWorkoutComplete(String workoutId, bool completed) =>
      _write(() async {
        final workouts = await _local.getWorkouts();
        final index = workouts.indexWhere((w) => w['id'] == workoutId);
        if (index == -1) {
          throw const WorkoutStorageException(
              'This workout no longer exists. Refresh your saved workouts.');
        }
        if (workouts[index]['completed'] == completed) return;
        workouts[index]['completed'] = completed;
        if (completed) {
          // date is the activity day used by Home/Progress; createdAt remains intact.
          workouts[index]['date'] = DateTime.now().toIso8601String();
        }
        await _local.saveWorkouts(workouts);
      });

  Future<int> getWorkoutCount(String userId) => _local.getWorkoutCount();
  Future<int> getCurrentStreak(String userId) => _local.getStreak();

  Future<int> getTotalMinutes(String userId) async {
    final workouts = await getUserWorkouts(userId);
    return workouts
        .where((w) => w.completed)
        .fold<int>(0, (total, w) => total + w.durationMinutes);
  }

  Future<Map<String, int>> getMuscleGroupStats(String userId) async {
    final workouts = await getUserWorkouts(userId);
    final stats = <String, int>{};
    for (final workout in workouts.where((w) => w.completed)) {
      stats[workout.muscleGroup] = (stats[workout.muscleGroup] ?? 0) + 1;
    }
    return stats;
  }
}
