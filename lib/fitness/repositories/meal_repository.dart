import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class MealRepository {
  final LocalStorageService _local = LocalStorageService();
  final Uuid _uuid = const Uuid();

  Future<List<Meal>> getUserMeals(String userId, {int limit = 50}) async {
    try {
      final data = await _local.getMeals();
      final meals = data
          .map((m) => Meal(
                id: m['id'] ?? '',
                userId: m['userId'] ?? userId,
                name: m['name'] ?? '',
                mealTime: m['mealTime'] ?? '',
                calories: m['calories'] ?? 0,
                protein: (m['protein'] as num?)?.toDouble() ?? 0,
                carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
                fat: (m['fat'] as num?)?.toDouble() ?? 0,
                date: DateTime.parse(
                    m['date'] ?? DateTime.now().toIso8601String()),
                notes: m['notes'],
                createdAt: DateTime.parse(
                    m['createdAt'] ?? DateTime.now().toIso8601String()),
              ))
          .toList();

      meals.sort((a, b) => b.date.compareTo(a.date));
      return meals.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Meal>> getMealsByDate(String userId, DateTime date) async {
    final allMeals = await getUserMeals(userId);
    return allMeals
        .where((m) =>
            m.date.year == date.year &&
            m.date.month == date.month &&
            m.date.day == date.day)
        .toList();
  }

  Future<String> createMeal(Meal meal) async {
    final id = _uuid.v4();
    final meals = await _local.getMeals();

    meals.insert(0, {
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
    });

    await _local.saveMeals(meals);
    return id;
  }

  Future<void> updateMeal(Meal meal) async {
    final meals = await _local.getMeals();
    final index = meals.indexWhere((m) => m['id'] == meal.id);
    if (index != -1) {
      meals[index] = {
        'id': meal.id,
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
      await _local.saveMeals(meals);
    }
  }

  Future<void> deleteMeal(String mealId) async {
    final meals = await _local.getMeals();
    meals.removeWhere((m) => m['id'] == mealId);
    await _local.saveMeals(meals);
  }

  Future<Map<String, dynamic>> getDailyNutrition(
      String userId, DateTime date) async {
    final meals = await getMealsByDate(userId, date);

    int totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final meal in meals) {
      totalCalories += meal.calories;
      totalProtein += meal.protein;
      totalCarbs += meal.carbs;
      totalFat += meal.fat;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  Future<int> getTotalCalories(String userId, {int days = 7}) async {
    final meals = await getUserMeals(userId);
    final startDate = DateTime.now().subtract(Duration(days: days));

    int total = 0;
    for (final meal in meals) {
      if (meal.date.isAfter(startDate)) {
        total += meal.calories;
      }
    }
    return total;
  }
}
