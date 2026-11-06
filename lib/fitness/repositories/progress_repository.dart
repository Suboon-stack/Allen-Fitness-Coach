import 'package:allen/fitness/models/progress_model.dart';
import 'package:allen/fitness/models/progress_tracking_data.dart';
import 'package:allen/fitness/models/nutrition_tracker_data.dart';
import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'meal_repository.dart';

class ProgressStorageException implements Exception {
  const ProgressStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProgressRepository {
  ProgressRepository(
      {String? Function()? authenticatedUser, MealRepository? meals})
      : _authenticatedUser = authenticatedUser ?? _firebaseUser,
        _meals = meals ?? MealRepository();
  final LocalStorageService _local = LocalStorageService();
  final Uuid _uuid = const Uuid();
  final String? Function() _authenticatedUser;
  final MealRepository _meals;
  static String? _firebaseUser() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static Future<void>? _weightTail;
  static Future<T> _write<T>(Future<T> Function() action) {
    final previous = _weightTail;
    final result = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _weightTail = tail;
    return result.whenComplete(() {
      if (identical(_weightTail, tail)) _weightTail = null;
    });
  }

  void _owner(String userId) {
    if (userId.isEmpty || _authenticatedUser() != userId) {
      throw const ProgressStorageException(
          'Your session changed. Close this form and sign in again.');
    }
  }

  void _validate(WeightEntry entry) {
    if (!entry.weight.isFinite ||
        entry.weight <= 0 ||
        entry.weight > 1000 ||
        entry.userId.isEmpty ||
        (entry.notes?.length ?? 0) > 500 ||
        entry.date.isAfter(DateTime.now())) {
      throw const ProgressStorageException(
          'Enter a valid weight up to 1,000 kg and a date no later than now.');
    }
  }

  WeightEntry _weight(Map<String, dynamic> record) {
    final weight = record['weight'];
    if (weight is! num ||
        !weight.isFinite ||
        weight <= 0 ||
        weight > 1000 ||
        record['userId'] is! String ||
        record['date'] is! String ||
        record['id'] != null && record['id'] is! String ||
        record['notes'] != null && record['notes'] is! String) {
      throw const FormatException('Invalid weight record');
    }
    return WeightEntry(
        id: record['id'] ?? '',
        userId: record['userId'],
        weight: weight.toDouble(),
        date: DateTime.parse(record['date']).toLocal(),
        notes: record['notes'],
        createdAt:
            DateTime.parse(record['createdAt'] ?? record['date']).toLocal());
  }

  Future<List<WeightEntry>> getWeightEntries(String userId,
      {int limit = 100}) async {
    if (userId.isEmpty) return [];
    try {
      final pending = _weightTail;
      if (pending != null) await pending;
      final records = await _local.getWeights();
      final entries =
          records.where((r) => r['userId'] == userId).map(_weight).toList();
      final ids = <String>{};
      for (final e in entries) {
        if (e.id.isNotEmpty && !ids.add(e.id)) {
          throw const FormatException('Duplicate weight identity');
        }
      }
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries.take(limit).toList();
    } catch (_) {
      throw const ProgressStorageException(
          'Weight history couldn’t be read. Retry; your stored records have not been changed.');
    }
  }

  Future<WeightEntry?> getLatestWeight(String userId) async {
    // Preserve the nullable contract used by the existing Home/Profile screens.
    // Progress uses the strict history reader and presents a dedicated error.
    try {
      final entries = await getWeightEntries(userId, limit: 0x7fffffff);
      final past = entries.where((e) => !e.date.isAfter(DateTime.now()));
      return past.isEmpty ? null : past.first;
    } on ProgressStorageException {
      return null;
    }
  }

  Map<String, dynamic> _record(WeightEntry entry, String id) => {
        'id': id,
        'userId': entry.userId,
        'weight': entry.weight,
        'date': entry.date.toIso8601String(),
        'createdAt': entry.createdAt.toIso8601String(),
        if (entry.notes != null) 'notes': entry.notes,
      };
  Future<String> addWeightEntry(WeightEntry entry) async {
    _owner(entry.userId);
    _validate(entry);
    return _write(() async {
      _owner(entry.userId);
      final records = await _local.getWeights();
      _owner(entry.userId);
      final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
      final existing = records.where((r) => r['id'] == id).toList();
      if (existing.isNotEmpty) {
        if (existing.length != 1 || existing.single['userId'] != entry.userId) {
          throw const ProgressStorageException(
              'This weight identifier is unavailable. Close the form and retry.');
        }
        return id;
      }
      records.insert(0, _record(entry, id));
      await _local.saveWeights(records);
      return id;
    });
  }

  Future<void> updateWeightEntry(WeightEntry entry) async {
    _owner(entry.userId);
    _validate(entry);
    return _write(() async {
      _owner(entry.userId);
      final records = await _local.getWeights();
      _owner(entry.userId);
      final matches = records.where((r) => r['id'] == entry.id).toList();
      if (entry.id.isEmpty ||
          matches.length != 1 ||
          matches.single['userId'] != entry.userId) {
        throw const ProgressStorageException(
            'This weight record is unavailable for your account. Refresh your history.');
      }
      final index = records.indexOf(matches.single);
      // Only explicitly editable fields change. Keep identity, owner, exact
      // creation timestamp representation and every unknown stored field intact.
      _weight(matches.single);
      records[index] = {
        ...matches.single,
        'weight': entry.weight,
        'date': entry.date.toIso8601String(),
        'notes': entry.notes
      };
      await _local.saveWeights(records);
    });
  }

  Future<void> deleteWeightEntry(String entryId, {String? userId}) async {
    final owner = userId ?? _authenticatedUser() ?? '';
    _owner(owner);
    return _write(() async {
      _owner(owner);
      final records = await _local.getWeights();
      _owner(owner);
      final matches = records.where((r) => r['id'] == entryId).toList();
      if (entryId.isEmpty ||
          matches.length != 1 ||
          matches.single['userId'] != owner) {
        throw const ProgressStorageException(
            'This weight record is unavailable for your account. Refresh your history.');
      }
      records.remove(matches.single);
      await _local.saveWeights(records);
    });
  }

  Future<List<CompletedWorkout>> getCompletedWorkouts(String userId) async {
    final records = await _local.getWorkouts();
    final ids = <String>{};
    return records
        .where((r) => r['userId'] == userId && r['completed'] == true)
        .map((r) {
      if (r['id'] is! String ||
          (r['id'] as String).isEmpty ||
          !ids.add(r['id']) ||
          r['name'] is! String ||
          (r['name'] as String).trim().isEmpty ||
          r['durationMinutes'] is! int ||
          (r['durationMinutes'] as int) < 0) {
        throw const FormatException('Invalid completion record');
      }
      return CompletedWorkout(
          id: r['id'],
          name: r['name'],
          date: DateTime.parse(r['date']).toLocal(),
          plannedMinutes: r['durationMinutes']);
    }).toList();
  }

  Future<ProgressSnapshot> loadTracking(String userId) async {
    final failures = <ProgressSource>{};
    Future<T?> read<T>(
        ProgressSource source, Future<T> Function() action) async {
      try {
        return await action();
      } catch (_) {
        failures.add(source);
        return null;
      }
    }

    final values = await Future.wait<Object?>([
      read(ProgressSource.weights,
          () => getWeightEntries(userId, limit: 0x7fffffff)),
      read(ProgressSource.workouts, () => getCompletedWorkouts(userId)),
      read(ProgressSource.meals, () async {
        final meals = await _meals.getUserMeals(userId, limit: 0x7fffffff);
        NutritionTotals.fromMeals(meals);
        return meals;
      }),
      read(
          ProgressSource.goals,
          () async => NutritionGoals.fromStoredProfile(
              await _local.getUserProfile(userId: userId), userId)),
    ]);
    return ProgressSnapshot(
        weights: values[0] as List<WeightEntry>?,
        workouts: values[1] as List<CompletedWorkout>?,
        meals: values[2] as List<Meal>?,
        goals: values[3] as NutritionGoals?,
        unavailable: failures);
  }

  // Shared water behavior is deliberately unchanged; personal Progress never
  // interprets these device-level totals as account-owned history.
  Future<int> getTodayWaterIntake(String userId) => _local.getTodayWater();
  Future<String> addWaterIntake(String userId, int amount) async {
    await _local.addWater(amount);
    return _uuid.v4();
  }

  Future<void> deleteWaterIntake(String entryId) async {
    /* No individual water entries exist. */
  }
  Future<List<double>> getWeightHistory(String userId, {int days = 30}) async {
    final now = DateTime.now(),
        start = DateTime.now().subtract(Duration(days: days));
    final entries = (await getWeightEntries(userId, limit: 0x7fffffff))
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return entries.map((e) => e.weight).toList();
  }

  Future<Map<String, dynamic>> getProgressStats(String userId) async {
    final snapshot = await loadTracking(userId);
    if (snapshot.unavailable.isNotEmpty) {
      throw const ProgressStorageException(
          'Progress data couldn’t be read. Please retry.');
    }
    final now = DateTime.now();
    final week = ProgressViewData(
        snapshot: snapshot, period: ProgressPeriod.week, now: now);
    final month = ProgressViewData(
        snapshot: snapshot, period: ProgressPeriod.month, now: now);
    final weights = (snapshot.weights ?? [])
        .where((e) => !e.date.isAfter(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final start = weights.isEmpty ? null : weights.first.weight;
    final current = weights.isEmpty ? null : weights.last.weight;
    return {
      'totalWorkouts':
          snapshot.workouts!.where((w) => !w.date.isAfter(now)).length,
      'weeklyWorkouts': week.workouts.length,
      'monthlyWorkouts': month.workouts.length,
      'totalMeals': snapshot.meals!.where((m) => !m.date.isAfter(now)).length,
      'weeklyCalories': week.meals.fold<int>(0, (n, m) => n + m.calories),
      'monthlyCalories': month.meals.fold<int>(0, (n, m) => n + m.calories),
      'startWeight': start,
      'currentWeight': current,
      'weightChange': start == null || current == null ? null : current - start
    };
  }
}
