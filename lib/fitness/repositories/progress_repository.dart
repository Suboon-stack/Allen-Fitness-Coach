import 'package:allen/fitness/models/progress_model.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class ProgressRepository {
  final LocalStorageService _local = LocalStorageService();
  final Uuid _uuid = const Uuid();

  Future<List<WeightEntry>> getWeightEntries(String userId,
      {int limit = 100}) async {
    try {
      final data = await _local.getWeights();
      final entries = data
          .map((w) => WeightEntry(
                id: w['id'] ?? '',
                userId: w['userId'] ?? userId,
                weight: (w['weight'] as num?)?.toDouble() ?? 0,
                date: DateTime.parse(
                    w['date'] ?? DateTime.now().toIso8601String()),
                notes: w['notes'],
                createdAt: DateTime.parse(
                    w['createdAt'] ?? DateTime.now().toIso8601String()),
              ))
          .toList();

      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  Future<WeightEntry?> getLatestWeight(String userId) async {
    final entries = await getWeightEntries(userId);
    return entries.isNotEmpty ? entries.first : null;
  }

  Future<String> addWeightEntry(WeightEntry entry) async {
    await _local.addWeight(entry.weight);
    return entry.id;
  }

  Future<void> deleteWeightEntry(String entryId) async {
    final entries = await _local.getWeights();
    entries.removeWhere((w) => w['id'] == entryId);
    await _local.saveWeights(entries);
  }

  Future<int> getTodayWaterIntake(String userId) async {
    return await _local.getTodayWater();
  }

  Future<String> addWaterIntake(String userId, int amount) async {
    await _local.addWater(amount);
    return _uuid.v4();
  }

  Future<void> deleteWaterIntake(String entryId) async {
    // Not implemented for simplicity
  }

  Future<List<double>> getWeightHistory(String userId, {int days = 30}) async {
    final entries = await getWeightEntries(userId);
    final startDate = DateTime.now().subtract(Duration(days: days));

    final filtered = entries.where((e) => e.date.isAfter(startDate)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return filtered.map((e) => e.weight).toList();
  }

  Future<Map<String, dynamic>> getProgressStats(String userId) async {
    final workouts = await _local.getWorkouts();
    final meals = await _local.getMeals();
    final weights = await getWeightEntries(userId);

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    final monthStart = now.subtract(const Duration(days: 30));

    int weeklyWorkouts = 0;
    int monthlyWorkouts = 0;
    int weeklyCalories = 0;
    int monthlyCalories = 0;

    for (final w in workouts) {
      if (w['completed'] == true) {
        final date = DateTime.parse(w['date'] ?? '');
        if (date.isAfter(weekStart)) weeklyWorkouts++;
        if (date.isAfter(monthStart)) monthlyWorkouts++;
      }
    }

    for (final m in meals) {
      final date = DateTime.parse(m['date'] ?? '');
      if (date.isAfter(weekStart))
        weeklyCalories += (m['calories'] as num?)?.toInt() ?? 0;
      if (date.isAfter(monthStart))
        monthlyCalories += (m['calories'] as num?)?.toInt() ?? 0;
    }

    double? startWeight;
    double? currentWeight;

    if (weights.isNotEmpty) {
      final sorted = weights..sort((a, b) => a.date.compareTo(b.date));
      startWeight = sorted.first.weight;
      currentWeight = sorted.last.weight;
    }

    return {
      'totalWorkouts': workouts.where((w) => w['completed'] == true).length,
      'weeklyWorkouts': weeklyWorkouts,
      'monthlyWorkouts': monthlyWorkouts,
      'totalMeals': meals.length,
      'weeklyCalories': weeklyCalories,
      'monthlyCalories': monthlyCalories,
      'startWeight': startWeight,
      'currentWeight': currentWeight,
      'weightChange': currentWeight != null && startWeight != null
          ? currentWeight - startWeight
          : null,
    };
  }
}
