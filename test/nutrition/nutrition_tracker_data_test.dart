import 'package:allen/fitness/models/nutrition_tracker_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'meal_repository_test.dart' show sampleMeal;

void main() {
  test(
      'Only positive finite saved goals belonging to the current account are used',
      () {
    final goals = NutritionGoals.fromStoredProfile({
      'id': 'member',
      'targetCalories': 1800,
      'targetProtein': 120.5,
      'targetCarbs': 0,
      'targetFat': double.nan
    }, 'member');
    expect(goals.calories, 1800);
    expect(goals.protein, 120.5);
    expect(goals.carbs, isNull);
    expect(goals.fat, isNull);
    expect(
        NutritionGoals.fromStoredProfile(
                {'id': 'another', 'targetCalories': 2000}, 'member')
            .calories,
        isNull);
    expect(
        NutritionGoals.fromStoredProfile({'targetCalories': 2000}, 'member')
            .calories,
        isNull);
    expect(NutritionGoals.fromStoredProfile(null, 'member').calories, isNull);
  });
  test('Totals use only supplied records, including explicit zeroes', () {
    final totals = NutritionTotals.fromMeals(
        [sampleMeal('a'), sampleMeal('b', calories: 0)]);
    expect(totals.calories, 400);
    expect(totals.protein, 40);
    expect(totals.carbs, 120);
    expect(totals.fat, 20);
    expect(NutritionTotals.fromMeals([]).calories, 0);
    expect(() => NutritionTotals.fromMeals([sampleMeal('bad', calories: -1)]),
        throwsFormatException);
  });
}
