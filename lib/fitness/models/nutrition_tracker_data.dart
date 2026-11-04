import 'meal_model.dart';

/// A read-only projection of existing profile fields; no target defaults/writes.
class NutritionGoals {
  const NutritionGoals({this.calories, this.protein, this.carbs, this.fat});
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  factory NutritionGoals.fromStoredProfile(
      Map<String, dynamic>? profile, String userId) {
    if (profile == null || profile['id'] != userId) {
      return const NutritionGoals();
    }
    double? valid(Object? value) =>
        value is num && value.isFinite && value > 0 ? value.toDouble() : null;
    return NutritionGoals(
        calories: valid(profile['targetCalories']),
        protein: valid(profile['targetProtein']),
        carbs: valid(profile['targetCarbs']),
        fat: valid(profile['targetFat']));
  }
}

class NutritionTotals {
  const NutritionTotals(
      {required this.calories,
      required this.protein,
      required this.carbs,
      required this.fat});
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  factory NutritionTotals.fromMeals(List<Meal> meals) {
    var calories = 0;
    var protein = 0.0, carbs = 0.0, fat = 0.0;
    for (final meal in meals) {
      if (meal.calories < 0 ||
          [meal.protein, meal.carbs, meal.fat]
              .any((v) => !v.isFinite || v < 0)) {
        throw const FormatException('Invalid recorded nutrition');
      }
      final nextCalories = calories + meal.calories;
      if (nextCalories < calories) {
        throw const FormatException('Invalid calorie total');
      }
      calories = nextCalories;
      protein += meal.protein;
      carbs += meal.carbs;
      fat += meal.fat;
    }
    if (calories < 0 || [protein, carbs, fat].any((v) => !v.isFinite)) {
      throw const FormatException('Invalid nutrition totals');
    }
    return NutritionTotals(
        calories: calories, protein: protein, carbs: carbs, fat: fat);
  }
}
