import 'dart:async';
import 'dart:io';
import 'package:allen/fitness/controllers/food_scanner_controller.dart';
import 'package:allen/fitness/models/food_estimate.dart';
import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEstimate estimate({String name = 'Rice bowl', int calories = 450}) =>
    FoodEstimate(
        name: name, calories: calories, protein: 20, carbs: 60, fat: 12);

class ScannerAi extends AiService {
  final calls = <Completer<FoodEstimate>>[];
  int cancels = 0;
  @override
  Future<FoodEstimate> analyzeFoodEstimate(File file) {
    final result = Completer<FoodEstimate>();
    calls.add(result);
    return result.future;
  }

  @override
  void cancelFoodAnalysis() {
    cancels++;
  }
}

class UncertainMealRepo extends MealRepository {
  int calls = 0;
  @override
  Future<String> createMeal(Meal meal) async {
    final id = await super.createMeal(meal);
    if (++calls == 1) throw StateError('private');
    return id;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ScannerAi ai;
  late MealRepository repo;
  late FoodScannerController scan;
  String? owner;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ai = ScannerAi();
    repo = MealRepository();
    owner = 'member';
    scan = FoodScannerController(
        service: ai, repository: repo, currentUser: () => owner);
  });
  tearDown(() => scan.dispose());
  Future<void> generate() async {
    scan.select(File('/unused-photo'));
    final pending = scan.analyze();
    ai.calls.last.complete(estimate());
    await pending;
  }

  test(
      'Selection is local; explicit analysis runs once and duplicate pending calls blocked',
      () async {
    scan.select(File('/photo'));
    expect(ai.calls, isEmpty);
    expect(scan.estimate, isNull);
    final pending = scan.analyze();
    await scan.analyze();
    expect(ai.calls.length, 1);
    expect(scan.analyzing, isTrue);
    ai.calls.single.complete(estimate());
    await pending;
    expect(scan.analyzing, isFalse);
    expect(scan.estimate!.calories, 450);
    expect(await repo.getUserMeals('member'), isEmpty);
  });
  test('Failures preserve photo; safe message and explicit retry', () async {
    scan.select(File('/photo'));
    var pending = scan.analyze();
    ai.calls.last.completeError(StateError('private-key'));
    await pending;
    expect(scan.error, isNot(contains('private')));
    expect(scan.image, isNotNull);
    pending = scan.analyze();
    ai.calls.last.complete(estimate());
    await pending;
    expect(scan.error, isNull);
    expect(scan.estimate, isNotNull);
  });
  test('Clear and new selection invalidate older image response', () async {
    scan.select(File('/first'));
    final first = scan.analyze();
    scan.clear();
    scan.select(File('/second'));
    final second = scan.analyze();
    ai.calls[0].complete(estimate(name: 'Stale'));
    await first;
    expect(scan.estimate, isNull);
    expect(scan.analyzing, isTrue);
    ai.calls[1].complete(estimate(name: 'Current'));
    await second;
    expect(scan.estimate!.name, 'Current');
  });
  test('Account switch clears temporary image and rejects stale response/save',
      () async {
    scan.select(File('/photo'));
    final pending = scan.analyze();
    owner = 'other';
    scan.syncUser();
    ai.calls.single.complete(estimate());
    await pending;
    expect(scan.image, isNull);
    expect(scan.estimate, isNull);
    expect(scan.analyzing, isFalse);
    expect(await scan.save(mealTime: 'Lunch'), isFalse);
    expect(await repo.getUserMeals('other'), isEmpty);
  });
  test('Leaving screen ignores pending completion before disposal', () async {
    scan.select(File('/photo'));
    final pending = scan.analyze();
    var notifications = 0;
    scan.addListener(() => notifications++);
    scan.abandon();
    ai.calls.single.complete(estimate());
    await pending;
    expect(notifications, 0);
    expect(scan.active, isFalse);
    expect(await scan.save(mealTime: 'Lunch'), isFalse);
  });
  test(
      'Edit then confirm persists real reviewed values once and new repository retrieves totals',
      () async {
    await generate();
    scan.edit(estimate(name: 'Reviewed rice', calories: 500));
    final saves = await Future.wait(
        [scan.save(mealTime: 'Dinner'), scan.save(mealTime: 'Dinner')]);
    expect(saves, [true, false]);
    expect(scan.saved, isTrue);
    expect(await scan.save(mealTime: 'Dinner'), isFalse);
    final fresh = MealRepository();
    final meals = await fresh.getUserMeals('member');
    expect(meals.length, 1);
    expect(meals.single.name, 'Reviewed rice');
    expect(meals.single.mealTime, 'Dinner');
    expect(meals.single.notes, startsWith(FoodEstimate.notePrefix));
    expect(
        (await fresh.getDailyNutrition('member', DateTime.now()))['calories'],
        500);
    expect(await fresh.getUserMeals('other'), isEmpty);
  });
  test(
      'Uncertain native acknowledgment retries same UUID and reconciles edits without duplicate records',
      () async {
    scan.dispose();
    repo = UncertainMealRepo();
    scan = FoodScannerController(
        service: ai, repository: repo, currentUser: () => owner);
    await generate();
    expect(await scan.save(mealTime: 'Lunch'), isFalse);
    expect(scan.error, isNotNull);
    final previous = (await repo.getUserMeals('member')).single;
    scan.edit(estimate(calories: 600));
    expect(await scan.save(mealTime: 'Dinner'), isTrue);
    final records = await repo.getUserMeals('member');
    expect(records.length, 1);
    expect(records.single.id, previous.id);
    expect(records.single.date, previous.date);
    expect(records.single.calories, 600);
  });
  test('No verified account means no submission or save', () async {
    owner = null;
    scan.syncUser();
    expect(scan.select(File('/photo')), isFalse);
    await scan.analyze();
    expect(ai.calls, isEmpty);
    expect(await scan.save(mealTime: 'Lunch'), isFalse);
  });
}
