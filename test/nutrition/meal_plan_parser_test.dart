import 'package:allen/fitness/services/meal_plan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const fullPlan =
    'Breakfast | Oats | 400 kcal | 20g protein | 60g carbs | 10g fat\n'
    'Lunch | Rice bowl | 600 | 30 | 80 | 15\n'
    'Dinner | Beans and vegetables | 500 | 25 | 70 | 12\n'
    'Snack | Yogurt | 200 | 12.5 | 20 | 5';

void main() {
  test('Preserves supplied values and totals without filling in missing macros',
      () {
    final meals = MealPlanParser.parse(fullPlan);
    expect(meals.length, 4);
    expect(meals.last.protein, 12.5);
    expect(meals.first.carbs, 60);
    expect(meals.fold<int>(0, (sum, m) => sum + m.calories), 1700);
    final older = fullPlan
        .split('\n')
        .map((line) => line.split('|').take(4).join('|'))
        .join('\n');
    expect(
        MealPlanParser.parse(older)
            .every((m) => m.carbs == null && m.fat == null),
        isTrue);
  });
  test('Accepts a markdown table with a header, without logging the header',
      () {
    final table =
        '| MEAL_TIME | MEAL_NAME | CALORIES | PROTEIN | CARBS | FAT |\n|---|---|---|---|---|---|\n${fullPlan.split('\n').map((l) => '| $l |').join('\n')}';
    expect(MealPlanParser.parse(table).first.name, 'Oats');
  });
  for (final input in [
    '',
    'Error: unavailable',
    fullPlan.split('\n').first,
    fullPlan.replaceFirst('20g protein', 'NaN'),
    fullPlan.replaceFirst('400 kcal', '0 kcal'),
    fullPlan.replaceFirst('60g carbs', '-1'),
    fullPlan.replaceFirst('Snack |', 'Lunch |'),
    '$fullPlan\nHere is your plan',
    fullPlan.replaceFirst('20g protein', 'a little protein')
  ]) {
    test(
        'Rejects invalid or incomplete plan: $input',
        () => expect(() => MealPlanParser.parse(input),
            throwsA(isA<MealGenerationException>())));
  }
}
