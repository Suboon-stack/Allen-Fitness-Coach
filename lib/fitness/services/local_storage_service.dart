import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // User Profile
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final prefs = await _prefs;
    await prefs.setString('user_profile', jsonEncode(profile));
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await _prefs;
    final data = prefs.getString('user_profile');
    return data != null ? jsonDecode(data) : null;
  }

  // Workouts
  Future<void> saveWorkouts(List<Map<String, dynamic>> workouts) async {
    final prefs = await _prefs;
    await prefs.setString('workouts', jsonEncode(workouts));
  }

  Future<List<Map<String, dynamic>>> getWorkouts() async {
    final prefs = await _prefs;
    final data = prefs.getString('workouts');
    return data != null
        ? List<Map<String, dynamic>>.from(jsonDecode(data))
        : [];
  }

  // Meals
  Future<void> saveMeals(List<Map<String, dynamic>> meals) async {
    final prefs = await _prefs;
    await prefs.setString('meals', jsonEncode(meals));
  }

  Future<List<Map<String, dynamic>>> getMeals() async {
    final prefs = await _prefs;
    final data = prefs.getString('meals');
    return data != null
        ? List<Map<String, dynamic>>.from(jsonDecode(data))
        : [];
  }

  // Weights
  Future<void> saveWeights(List<Map<String, dynamic>> weights) async {
    final prefs = await _prefs;
    await prefs.setString('weights', jsonEncode(weights));
  }

  Future<List<Map<String, dynamic>>> getWeights() async {
    final prefs = await _prefs;
    final data = prefs.getString('weights');
    return data != null
        ? List<Map<String, dynamic>>.from(jsonDecode(data))
        : [];
  }

  Future<void> addWeight(double weight) async {
    final weights = await getWeights();
    weights.insert(0, {
      'weight': weight,
      'date': DateTime.now().toIso8601String(),
    });
    await saveWeights(weights);
  }

  // Water
  Future<void> addWater(int amount) async {
    final prefs = await _prefs;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final current = prefs.getInt('water_$today') ?? 0;
    await prefs.setInt('water_$today', current + amount);
  }

  Future<int> getTodayWater() async {
    final prefs = await _prefs;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return prefs.getInt('water_$today') ?? 0;
  }

  // Stats
  Future<int> getWorkoutCount() async {
    final workouts = await getWorkouts();
    return workouts.where((w) => w['completed'] == true).length;
  }

  Future<int> getStreak() async {
    final workouts = await getWorkouts();
    if (workouts.isEmpty) return 0;

    final completedWorkouts =
        workouts.where((w) => w['completed'] == true).toList();
    if (completedWorkouts.isEmpty) return 0;

    int streak = 0;
    DateTime checkDate = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final dayStart = DateTime(checkDate.year, checkDate.month, checkDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      bool hasWorkout = false;
      for (final w in completedWorkouts) {
        final date = DateTime.parse(w['date']);
        if (date.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
            date.isBefore(dayEnd)) {
          hasWorkout = true;
          break;
        }
      }

      if (hasWorkout) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (i == 0) {
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}
