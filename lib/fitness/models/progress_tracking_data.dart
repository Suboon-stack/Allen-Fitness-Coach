import 'dart:math' as math;
import 'meal_model.dart';
import 'nutrition_tracker_data.dart';
import 'progress_model.dart';

enum ProgressPeriod {
  week('7D'),
  month('30D'),
  quarter('3M'),
  year('1Y');

  const ProgressPeriod(this.label);
  final String label;
  DateTime start(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return switch (this) {
      week => DateTime(day.year, day.month, day.day - 6),
      month => DateTime(day.year, day.month, day.day - 29),
      quarter => _monthsBefore(day, 3),
      year => _monthsBefore(day, 12),
    };
  }

  static DateTime _monthsBefore(DateTime day, int months) {
    final month = DateTime(day.year, day.month - months);
    return DateTime(month.year, month.month,
        math.min(day.day, DateTime(month.year, month.month + 1, 0).day));
  }

  bool contains(DateTime date, DateTime now) =>
      !date.toLocal().isBefore(start(now)) && !date.isAfter(now);
}

enum ProgressSource { weights, workouts, meals, goals }

class CompletedWorkout {
  const CompletedWorkout(
      {required this.id,
      required this.name,
      required this.date,
      required this.plannedMinutes});
  final String id, name;
  final DateTime date;
  final int plannedMinutes;
}

/// Null means unavailable, an empty list means a successful read with no records.
class ProgressSnapshot {
  ProgressSnapshot(
      {this.weights,
      this.workouts,
      this.meals,
      this.goals,
      Set<ProgressSource> unavailable = const {}})
      : unavailable = Set.unmodifiable(unavailable);
  final List<WeightEntry>? weights;
  final List<CompletedWorkout>? workouts;
  final List<Meal>? meals;
  final NutritionGoals? goals;
  final Set<ProgressSource> unavailable;
}

enum ProgressEventKind { weight, workout, meal, milestone }

class ProgressEvent {
  const ProgressEvent(
      {required this.id,
      required this.kind,
      required this.date,
      required this.title,
      required this.detail,
      this.weight,
      this.estimated = false});
  final String id, title, detail;
  final ProgressEventKind kind;
  final DateTime date;
  final WeightEntry? weight;
  final bool estimated;
}

/// Pure date filtering and aggregation; no guessed goals, burn or water values.
class ProgressViewData {
  ProgressViewData(
      {required this.snapshot, required this.period, required this.now});
  final ProgressSnapshot snapshot;
  final ProgressPeriod period;
  final DateTime now;
  List<WeightEntry> get weights => (snapshot.weights ?? [])
      .where((e) => period.contains(e.date, now))
      .toList()
    ..sort((a, b) {
      final date = a.date.compareTo(b.date);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
  List<CompletedWorkout> get workouts => (snapshot.workouts ?? [])
      .where((e) => period.contains(e.date, now))
      .toList();
  List<Meal> get meals => (snapshot.meals ?? [])
      .where((e) => period.contains(e.date, now))
      .toList();
  List<Meal> get todayMeals => (snapshot.meals ?? []).where((m) {
        final d = m.date.toLocal();
        return !d.isAfter(now) &&
            d.year == now.year &&
            d.month == now.month &&
            d.day == now.day;
      }).toList();
  NutritionTotals? get todayNutrition =>
      snapshot.meals == null || todayMeals.isEmpty
          ? null
          : NutritionTotals.fromMeals(todayMeals);
  double? get weightChange =>
      weights.length < 2 ? null : weights.last.weight - weights.first.weight;
  bool get showProtein =>
      todayNutrition != null && snapshot.goals?.protein != null;
  String get journeySummary {
    final count = weights.length;
    if (count >= 2) {
      final change = weightChange!;
      return '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg across $count check-ins';
    }
    if (count == 1) return 'Your first check-in in this period';
    if (workouts.isNotEmpty) {
      return '${workouts.length} recorded workout${workouts.length == 1 ? '' : 's'} completed';
    }
    if (meals.isNotEmpty) {
      return '${meals.length} meal${meals.length == 1 ? '' : 's'} recorded';
    }
    return 'Your journey, at your pace';
  }

  List<ProgressEvent> get timeline {
    final events = <ProgressEvent>[
      for (final entry in weights)
        ProgressEvent(
            id: 'weight-${entry.id}-${entry.date.microsecondsSinceEpoch}',
            kind: ProgressEventKind.weight,
            date: entry.date,
            title: 'Weight logged',
            detail: '${entry.weight.toStringAsFixed(1)} kg',
            weight: entry),
      for (final entry in workouts)
        ProgressEvent(
            id: 'workout-${entry.id}',
            kind: ProgressEventKind.workout,
            date: entry.date,
            title: entry.name,
            detail: entry.plannedMinutes > 0
                ? 'Completed · ${entry.plannedMinutes} min plan'
                : 'Recorded completion'),
      for (final entry in meals)
        ProgressEvent(
            id: 'meal-${entry.id}-${entry.date.microsecondsSinceEpoch}',
            kind: ProgressEventKind.meal,
            date: entry.date,
            title: entry.name,
            detail: '${entry.mealTime} · ${entry.calories} kcal recorded',
            estimated: entry.notes?.startsWith('AI photo estimate') ?? false),
    ];
    // Derive a genuine milestone from recorded owned history, never an invented
    // streak. Acknowledge that it is first *recorded*, not necessarily first-ever.
    final allWeights = (snapshot.weights ?? [])
        .where((e) => !e.date.isAfter(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (allWeights.isNotEmpty && period.contains(allWeights.first.date, now)) {
      events.add(ProgressEvent(
          id: 'milestone-first-check-in',
          kind: ProgressEventKind.milestone,
          date: allWeights.first.date,
          title: 'First recorded weight check-in',
          detail: 'A starting point in your saved history'));
    }
    events.sort((a, b) {
      final date = b.date.compareTo(a.date);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return events;
  }
}
