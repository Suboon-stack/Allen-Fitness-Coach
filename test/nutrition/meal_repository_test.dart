import 'dart:convert';
import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Meal sampleMeal(String id,
    {String user = 'member', int calories = 400, DateTime? date}) {
  final day = date ?? DateTime.now();
  return Meal(
      id: id,
      userId: user,
      name: 'Oats',
      mealTime: 'Breakfast',
      calories: calories,
      protein: 20,
      carbs: 60,
      fat: 10,
      date: day,
      createdAt: day);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Stable draft saves once, concurrent requests preserve distinct records',
      () async {
    final repo = MealRepository();
    final results = await Future.wait([
      repo.createMeal(sampleMeal('draft')),
      MealRepository().createMeal(sampleMeal('draft')),
      repo.createMeal(sampleMeal('other'))
    ]);
    expect(results, ['draft', 'draft', 'other']);
    expect((await repo.getUserMeals('member')).length, 2);
    expect(await repo.createMeal(sampleMeal('')), isNotEmpty);
  });
  test(
      'Reads filter existing account IDs while unowned and foreign records remain stored',
      () async {
    final repo = MealRepository();
    await repo.createMeal(sampleMeal('a'));
    await repo.createMeal(sampleMeal('b', user: 'another'));
    final local = LocalStorageService();
    final raw = await local.getMeals();
    raw.add({...raw.first, 'id': 'legacy', 'userId': null});
    await local.saveMeals(raw);
    expect((await repo.getUserMeals('member')).map((m) => m.id), ['a']);
    expect((await repo.getDailyNutrition('member', DateTime.now()))['calories'],
        400);
    expect((await local.getMeals()).length, 3);
    await expectLater(repo.createMeal(sampleMeal('a', user: 'another')),
        throwsA(isA<MealStorageException>()));
  });
  test('Daily totals and today list include more than the history limit',
      () async {
    final repo = MealRepository();
    final now = DateTime.now();
    for (var i = 0; i < 55; i++) {
      await repo.createMeal(sampleMeal('today-$i', date: now));
    }
    await repo.createMeal(
        sampleMeal('yesterday', date: now.subtract(const Duration(days: 1))));
    expect((await repo.getUserMeals('member')).length, 50);
    expect((await repo.getMealsByDate('member', now)).length, 55);
    expect(await repo.getDailyNutrition('member', now),
        {'calories': 22000, 'protein': 1100.0, 'carbs': 3300.0, 'fat': 550.0});
  });
  test('Corrupt data errors explicitly without overwriting stored bytes',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meals', 'not-json');
    await expectLater(MealRepository().getUserMeals('member'),
        throwsA(isA<MealStorageException>()));
    await expectLater(
        MealRepository().createMeal(sampleMeal('new')), throwsA(anything));
    expect(prefs.getString('meals'), 'not-json');
  });
  test('Existing fields, update/delete and serialized schema are preserved',
      () async {
    final repo = MealRepository();
    await repo.createMeal(sampleMeal('saved'));
    final local = LocalStorageService();
    final raw = await local.getMeals();
    raw.first['legacyExtra'] = 'keep';
    await local.saveMeals(raw);
    await repo.updateMeal(sampleMeal('saved', calories: 450));
    expect((await local.getMeals()).first['legacyExtra'], 'keep');
    final stored =
        jsonDecode((await SharedPreferences.getInstance()).getString('meals')!)
            as List;
    expect(stored.first['carbs'], 60.0);
    await repo.deleteMeal('saved');
    expect(await repo.getUserMeals('member'), isEmpty);
  });
  test('Incomplete stored macros are not converted to fabricated zeroes',
      () async {
    final repo = MealRepository();
    await repo.createMeal(sampleMeal('saved'));
    final local = LocalStorageService();
    final raw = await local.getMeals();
    raw.first.remove('fat');
    await local.saveMeals(raw);
    final before = (await SharedPreferences.getInstance()).getString('meals');
    await expectLater(repo.getDailyNutrition('member', DateTime.now()),
        throwsA(isA<MealStorageException>()));
    expect((await SharedPreferences.getInstance()).getString('meals'), before);
  });
  test('Invalid new nutrition is rejected without creating a record', () async {
    await expectLater(
        MealRepository().createMeal(sampleMeal('invalid', calories: -1)),
        throwsA(isA<MealStorageException>()));
    expect(await LocalStorageService().getMeals(), isEmpty);
  });
}
