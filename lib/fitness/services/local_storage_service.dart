import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WaterStorageException implements Exception {
  const WaterStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();

  bool _workoutsNeedReload = false;
  bool _mealsNeedReload = false;
  bool _waterNeedsReload = false;
  bool _weightsNeedReload = false;
  bool _profilesNeedReload = false;
  Future<void>? _waterWriteTail;
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // User Profile
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final prefs = await _prefs;
    await prefs.setString('user_profile', jsonEncode(profile));
  }

  Future<Map<String, dynamic>?> getUserProfile({String? userId}) async {
    final prefs = await _prefs;
    if (_profilesNeedReload) {
      await prefs.reload();
      _profilesNeedReload = false;
    }
    if (userId != null) {
      if (userId.isEmpty) return null;
      final owned =
          prefs.getString('user_profile_${Uri.encodeComponent(userId)}');
      if (owned != null) {
        final data = Map<String, dynamic>.from(jsonDecode(owned) as Map);
        if (data['id'] != userId) {
          throw const FormatException('Invalid profile ownership');
        }
        return data;
      }
    }
    final raw = prefs.getString('user_profile');
    if (raw == null) return null;
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return userId == null || data['id'] == userId ? data : null;
  }

  // New writes never replace, claim or delete the shared legacy profile.
  Future<void> saveOwnedUserProfile(
      String userId, Map<String, dynamic> profile) async {
    if (userId.isEmpty || profile['id'] != userId) {
      throw ArgumentError('Profile owner mismatch');
    }
    final prefs = await _prefs;
    try {
      if (!await prefs.setString(
          'user_profile_${Uri.encodeComponent(userId)}', jsonEncode(profile))) {
        throw StateError('Profile persistence was not confirmed');
      }
    } catch (_) {
      _profilesNeedReload = true;
      try {
        await prefs.reload();
        _profilesNeedReload = false;
      } catch (_) {/* Verify cache before the next read. */}
      rethrow;
    }
  }

  // Workouts
  Future<void> saveWorkouts(List<Map<String, dynamic>> workouts) async {
    final prefs = await _prefs;
    try {
      final saved = await prefs.setString('workouts', jsonEncode(workouts));
      if (!saved) throw StateError('Workout persistence was not confirmed');
    } catch (_) {
      // SharedPreferences changes its cache before the platform confirms a
      // write. Never let an uncertain cached record masquerade as persisted.
      _workoutsNeedReload = true;
      try {
        await prefs.reload();
        _workoutsNeedReload = false;
      } catch (_) {
        // The next workout read must verify the platform state before use.
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getWorkouts() async {
    final prefs = await _prefs;
    if (_workoutsNeedReload) {
      await prefs.reload();
      _workoutsNeedReload = false;
    }
    final data = prefs.getString('workouts');
    return data != null
        ? List<Map<String, dynamic>>.from(jsonDecode(data))
        : [];
  }

  // Meals
  Future<void> saveMeals(List<Map<String, dynamic>> meals) async {
    final prefs = await _prefs;
    try {
      if (!await prefs.setString('meals', jsonEncode(meals))) {
        throw StateError('Meal persistence was not confirmed');
      }
    } catch (_) {
      _mealsNeedReload = true;
      try {
        await prefs.reload();
        _mealsNeedReload = false;
      } catch (_) {
        // A subsequent read must verify native state before confirming a retry.
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMeals() async {
    final prefs = await _prefs;
    if (_mealsNeedReload) {
      await prefs.reload();
      _mealsNeedReload = false;
    }
    final data = prefs.getString('meals');
    return data != null
        ? List<Map<String, dynamic>>.from(jsonDecode(data))
        : [];
  }

  // Weights
  Future<void> saveWeights(List<Map<String, dynamic>> weights) async {
    final prefs = await _prefs;
    try {
      if (!await prefs.setString('weights', jsonEncode(weights))) {
        throw StateError('Weight persistence was not confirmed');
      }
    } catch (_) {
      _weightsNeedReload = true;
      try {
        await prefs.reload();
        _weightsNeedReload = false;
      } catch (_) {/* Retry read must verify native state. */}
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getWeights() async {
    final prefs = await _prefs;
    if (_weightsNeedReload) {
      await prefs.reload();
      _weightsNeedReload = false;
    }
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
  Future<void> addWater(int amount) {
    if (amount <= 0) {
      return Future.error(
          ArgumentError.value(amount, 'amount', 'Must be positive'));
    }
    // Capture the requested day before queuing. Keep the existing date-only key.
    final key = _todayWaterKey();
    final previous = _waterWriteTail;
    Future<void> write() async {
      final prefs = await _prefs;
      if (_waterNeedsReload) {
        await prefs.reload();
        _waterNeedsReload = false;
      }
      final current = _waterValue(prefs, key);
      final next = current + amount;
      if (next < current) throw StateError('Water amount is too large');
      try {
        if (!await prefs.setInt(key, next)) {
          throw StateError('Water write not acknowledged');
        }
      } catch (_) {
        _waterNeedsReload = true;
        try {
          await prefs.reload();
          _waterNeedsReload = false;
          // A native write can succeed even if acknowledgement is lost. Confirm
          // the total before exposing a retry that would count it twice.
          if (_waterValue(prefs, key) == next) return;
        } catch (_) {
          // Require the next read to verify actual platform state.
          _waterNeedsReload = true;
        }
        throw const WaterStorageException(
            'Water save couldn’t be confirmed. Refresh your total before adding again.');
      }
    }

    final result = previous == null
        ? Future<void>.sync(write)
        : previous.then((_) => write());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _waterWriteTail = tail;
    return result.whenComplete(() {
      if (identical(_waterWriteTail, tail)) _waterWriteTail = null;
    });
  }

  Future<int> getTodayWater() async {
    // Readers, including Home, must wait for an in-flight native write instead
    // of treating SharedPreferences' optimistic cache as confirmed storage.
    final pending = _waterWriteTail;
    if (pending != null) await pending;
    final prefs = await _prefs;
    if (_waterNeedsReload) {
      await prefs.reload();
      _waterNeedsReload = false;
    }
    return _waterValue(prefs, _todayWaterKey());
  }

  String _todayWaterKey() =>
      'water_${DateTime.now().toIso8601String().substring(0, 10)}';

  int _waterValue(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    if (value == null) return 0;
    if (value is! int || value < 0) {
      throw const WaterStorageException(
          'Today’s water total couldn’t be read. Your stored data has not been changed.');
    }
    return value;
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
