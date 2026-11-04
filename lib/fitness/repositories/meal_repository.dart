import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class MealStorageException implements Exception {
  const MealStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MealRepository {
  final LocalStorageService _local = LocalStorageService();
  final Uuid _uuid = const Uuid();
  static Future<void>? _writeTail;

  static Future<T> _write<T>(Future<T> Function() action) {
    final previous = _writeTail;
    final result = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _writeTail = tail;
    return result.whenComplete(() {
      if (identical(_writeTail, tail)) _writeTail = null;
    });
  }

  Future<List<Meal>> _readUserMeals(String userId) async {
    try {
      final data = await _local.getMeals();
      // Read existing ownership metadata. Never assign unowned legacy records to
      // whichever account happens to open Nutrition; raw records stay intact.
      final meals = data.where((m) => m['userId'] == userId).map((m) {
        // Missing or malformed nutrition is unknown, not a recorded zero.
        final calories = m['calories'];
        if (m['name'] is! String ||
            (m['name'] as String).trim().isEmpty ||
            m['mealTime'] is! String ||
            (m['mealTime'] as String).trim().isEmpty ||
            calories is! int ||
            calories < 0 ||
            ['protein', 'carbs', 'fat'].any((key) =>
                m[key] is! num ||
                !(m[key] as num).isFinite ||
                (m[key] as num) < 0)) {
          throw const FormatException('Invalid stored nutrition');
        }
        return Meal(
          id: m['id'] ?? '',
          userId: m['userId'],
          name: m['name'] ?? '',
          mealTime: m['mealTime'] ?? '',
          calories: calories,
          protein: (m['protein'] as num).toDouble(),
          carbs: (m['carbs'] as num).toDouble(),
          fat: (m['fat'] as num).toDouble(),
          date: DateTime.parse(m['date']).toLocal(),
          notes: m['notes'],
          createdAt: DateTime.parse(m['createdAt'] ?? m['date']).toLocal(),
        );
      }).toList();
      meals.sort((a, b) => b.date.compareTo(a.date));
      return meals;
    } catch (_) {
      throw const MealStorageException(
          'Saved meals couldn’t be read. Please retry. Your stored records have not been deleted.');
    }
  }

  Future<List<Meal>> getUserMeals(String userId, {int limit = 50}) async =>
      (await _readUserMeals(userId)).take(limit).toList();

  Future<List<Meal>> getMealsByDate(String userId, DateTime date) async {
    final day = date.toLocal();
    return (await _readUserMeals(userId))
        .where((m) =>
            m.date.year == day.year &&
            m.date.month == day.month &&
            m.date.day == day.day)
        .toList();
  }

  Future<String> createMeal(Meal meal) => _write(() async {
        _validateMeal(meal);
        final id = meal.id.isEmpty ? _uuid.v4() : meal.id;
        final records = await _local.getMeals();
        final existing = records.where((m) => m['id'] == id);
        if (existing.isNotEmpty) {
          if (existing.first['userId'] != meal.userId) {
            throw const MealStorageException(
                'This meal identifier is already in use. Please retry with a new meal.');
          }
          return id;
        }
        records.insert(0, _record(meal, id));
        await _local.saveMeals(records);
        return id;
      });

  Future<void> updateMeal(Meal meal) => _write(() async {
        _validateMeal(meal);
        final records = await _local.getMeals();
        final index = records.indexWhere(
            (m) => m['id'] == meal.id && m['userId'] == meal.userId);
        if (index == -1) {
          throw const MealStorageException(
              'This meal no longer exists. Refresh your meals.');
        }
        records[index] = {...records[index], ..._record(meal, meal.id)};
        await _local.saveMeals(records);
      });

  Future<void> deleteMeal(String mealId) => _write(() async {
        final records = await _local.getMeals();
        final index = records.indexWhere((m) => m['id'] == mealId);
        if (index == -1) {
          throw const MealStorageException(
              'This meal no longer exists. Refresh your meals.');
        }
        records.removeAt(index);
        await _local.saveMeals(records);
      });

  void _validateMeal(Meal meal) {
    if (meal.name.trim().isEmpty ||
        meal.mealTime.trim().isEmpty ||
        meal.calories < 0 ||
        [meal.protein, meal.carbs, meal.fat].any((v) => !v.isFinite || v < 0)) {
      throw const MealStorageException(
          'Enter a meal name, category, and valid nonnegative nutrition values.');
    }
  }

  Map<String, dynamic> _record(Meal meal, String id) => {
        'id': id,
        'userId': meal.userId,
        'name': meal.name,
        'mealTime': meal.mealTime,
        'calories': meal.calories,
        'protein': meal.protein,
        'carbs': meal.carbs,
        'fat': meal.fat,
        'date': meal.date.toIso8601String(),
        'notes': meal.notes,
        'createdAt': meal.createdAt.toIso8601String(),
      };

  Future<Map<String, dynamic>> getDailyNutrition(
      String userId, DateTime date) async {
    final meals = await getMealsByDate(userId, date);
    return {
      'calories': meals.fold<int>(0, (n, m) => n + m.calories),
      'protein': meals.fold<double>(0, (n, m) => n + m.protein),
      'carbs': meals.fold<double>(0, (n, m) => n + m.carbs),
      'fat': meals.fold<double>(0, (n, m) => n + m.fat),
    };
  }

  Future<int> getTotalCalories(String userId, {int days = 7}) async {
    final start = DateTime.now().subtract(Duration(days: days));
    final end = DateTime.now();
    return (await _readUserMeals(userId))
        .where((m) => m.date.isAfter(start) && !m.date.isAfter(end))
        .fold<int>(0, (n, m) => n + m.calories);
  }
}
