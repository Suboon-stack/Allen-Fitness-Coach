import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _weightKey = 'weight_logs';
  static const String _workoutCountKey = 'workout_count';
  static const String _streakKey = 'streak';
  static const String _lastWorkoutKey = 'last_workout_date';

  // ── Weight logs ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getWeightLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_weightKey) ?? [];
    return data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> addWeightLog(double weight) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getWeightLogs();
    logs.add({
      'weight': weight,
      'date': DateTime.now().toIso8601String(),
    });
    await prefs.setStringList(
      _weightKey,
      logs.map((e) => jsonEncode(e)).toList(),
    );
  }

  Future<void> clearWeightLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_weightKey);
  }

  // ── Workout count ─────────────────────────────────────────────
  Future<int> getWorkoutCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_workoutCountKey) ?? 0;
  }

  Future<void> incrementWorkoutCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = await getWorkoutCount();
    await prefs.setInt(_workoutCountKey, count + 1);

    // Update streak
    await _updateStreak();
  }

  // ── Streak ────────────────────────────────────────────────────
  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_lastWorkoutKey);

    if (lastDateStr == null) {
      await prefs.setInt(_streakKey, 1);
      await prefs.setString(
        _lastWorkoutKey,
        DateTime.now().toIso8601String(),
      );
      return;
    }

    final lastDate = DateTime.parse(lastDateStr);
    final today = DateTime.now();
    final diff = today.difference(lastDate).inDays;

    int streak = prefs.getInt(_streakKey) ?? 0;

    if (diff == 1) {
      streak++;
    } else if (diff > 1) {
      streak = 1;
    }

    await prefs.setInt(_streakKey, streak);
    await prefs.setString(
      _lastWorkoutKey,
      DateTime.now().toIso8601String(),
    );
  }

  // ── Latest weight ─────────────────────────────────────────────
  Future<double?> getLatestWeight() async {
    final logs = await getWeightLogs();
    if (logs.isEmpty) return null;
    return logs.last['weight'] as double;
  }
}
