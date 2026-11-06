import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/models/nutrition_tracker_data.dart';
import 'package:allen/fitness/models/progress_model.dart';
import 'package:allen/fitness/models/progress_tracking_data.dart';
import 'package:flutter_test/flutter_test.dart';

WeightEntry weight(String id, double value, DateTime date,
        {String owner = 'member'}) =>
    WeightEntry(
        id: id, userId: owner, weight: value, date: date, createdAt: date);
Meal meal(String id, DateTime date,
        {int calories = 400, double protein = 20}) =>
    Meal(
        id: id,
        userId: 'member',
        name: 'Rice',
        mealTime: 'Lunch',
        calories: calories,
        protein: protein,
        carbs: 60,
        fat: 10,
        date: date,
        createdAt: date);
void main() {
  final now = DateTime(2026, 11, 5, 12);
  test('7D and 30D use inclusive local calendar dates, exclude future times',
      () {
    expect(ProgressPeriod.week.start(now), DateTime(2026, 10, 30));
    expect(ProgressPeriod.month.start(now), DateTime(2026, 10, 7));
    expect(ProgressPeriod.week.contains(DateTime(2026, 10, 30), now), isTrue);
    expect(ProgressPeriod.week.contains(DateTime(2026, 10, 29, 23, 59), now),
        isFalse);
    expect(
        ProgressPeriod.week.contains(now.add(const Duration(minutes: 1)), now),
        isFalse);
  });
  test('3M and 1Y use calendar months with end-of-month/leap-day clamping', () {
    expect(ProgressPeriod.quarter.start(DateTime(2026, 5, 31)),
        DateTime(2026, 2, 28));
    expect(ProgressPeriod.year.start(DateTime(2024, 2, 29)),
        DateTime(2023, 2, 28));
    expect(ProgressPeriod.quarter.start(now), DateTime(2026, 8, 5));
    expect(ProgressPeriod.year.start(now), DateTime(2025, 11, 5));
  });
  test('History filters real timestamps and sorts without modifying input', () {
    final entries = [
      weight('new', 72, now),
      weight('old', 70, DateTime(2026, 9, 1)),
      weight('within', 71, DateTime(2026, 10, 20)),
      weight('future', 80, DateTime(2026, 11, 6))
    ];
    final data = ProgressViewData(
        snapshot: ProgressSnapshot(weights: entries),
        period: ProgressPeriod.month,
        now: now);
    expect(data.weights.map((e) => e.id), ['within', 'new']);
    expect(entries.first.id, 'new');
    expect(data.weightChange, 1);
    expect(data.journeySummary, contains('+1.0 kg'));
    expect(data.journeySummary, isNot(contains('lost')));
  });
  test('Empty/single-point data never produces a fabricated trend', () {
    var data = ProgressViewData(
        snapshot: ProgressSnapshot(weights: []),
        period: ProgressPeriod.month,
        now: now);
    expect(data.weightChange, isNull);
    expect(data.journeySummary, 'Your journey, at your pace');
    data = ProgressViewData(
        snapshot: ProgressSnapshot(weights: [weight('one', 70, now)]),
        period: ProgressPeriod.month,
        now: now);
    expect(data.weightChange, isNull);
    expect(data.journeySummary, contains('first check-in in this period'));
  });
  test(
      'Nutrition is today only, not selected-period totals masquerading as daily goals',
      () {
    final data = ProgressViewData(
        snapshot: ProgressSnapshot(meals: [
          meal('today', now),
          meal('yesterday', DateTime(2026, 11, 4)),
          meal('future', DateTime(2026, 11, 5, 13))
        ], goals: const NutritionGoals(calories: 2000, protein: 100)),
        period: ProgressPeriod.year,
        now: now);
    expect(data.meals.length, 2);
    expect(data.todayNutrition!.calories, 400);
    expect(data.todayNutrition!.protein, 20);
    expect(data.showProtein, isTrue);
  });
  test('Missing meals remain unknown, explicit recorded zero remains zero', () {
    for (final entries in [null, <Meal>[]]) {
      final data = ProgressViewData(
          snapshot: ProgressSnapshot(meals: entries),
          period: ProgressPeriod.month,
          now: now);
      expect(data.todayNutrition, isNull);
      expect(data.showProtein, isFalse);
    }
    final data = ProgressViewData(
        snapshot: ProgressSnapshot(
            meals: [meal('zero', now, calories: 0, protein: 0)]),
        period: ProgressPeriod.month,
        now: now);
    expect(data.todayNutrition!.calories, 0);
  });
  test(
      'Timeline includes real completions, dated meals and weights with stable order',
      () {
    final snapshot = ProgressSnapshot(weights: [
      weight('w', 70, DateTime(2026, 11, 4))
    ], workouts: [
      CompletedWorkout(
          id: 'done', name: 'Upper body', date: now, plannedMinutes: 45)
    ], meals: [
      meal('m', DateTime(2026, 11, 3))
    ]);
    final data = ProgressViewData(
        snapshot: snapshot, period: ProgressPeriod.week, now: now);
    expect(data.timeline.first.title, 'Upper body');
    expect(data.timeline.first.detail, 'Completed · 45 min plan');
    expect(
        data.timeline.where((e) => e.kind == ProgressEventKind.weight).length,
        1);
    expect(
        data.timeline
            .where((e) => e.kind == ProgressEventKind.milestone)
            .single
            .title,
        'First recorded weight check-in');
    expect(data.timeline.any((e) => e.detail.contains('burned')), isFalse);
    expect(data.timeline.map((e) => e.id).toSet().length, data.timeline.length);
  });
  test(
      'Milestone is anchored to earliest owned record, not first record in every filter',
      () {
    final data = ProgressViewData(
        snapshot: ProgressSnapshot(weights: [
          weight('old', 70, DateTime(2025, 1, 1)),
          weight('now', 71, now)
        ]),
        period: ProgressPeriod.week,
        now: now);
    expect(data.timeline.where((e) => e.kind == ProgressEventKind.milestone),
        isEmpty);
  });
  test('No hardcoded achievements, water events or calorie burn exist', () {
    final data = ProgressViewData(
        snapshot: ProgressSnapshot(weights: [], workouts: [], meals: []),
        period: ProgressPeriod.month,
        now: now);
    expect(data.timeline, isEmpty);
  });
}
