class MealGenerationException implements Exception {
  const MealGenerationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Values are provider estimates; missing macros remain unknown until reviewed.
class MealSuggestion {
  const MealSuggestion(
      {required this.mealTime,
      required this.name,
      required this.calories,
      required this.protein,
      this.carbs,
      this.fat});
  final String mealTime;
  final String name;
  final int calories;
  final double protein;
  final double? carbs;
  final double? fat;
}

abstract final class MealPlanParser {
  static List<MealSuggestion> parse(String source) {
    final result = <MealSuggestion>[];
    for (final raw in source.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line == '```' || line == '```text') continue;
      final cells = line.split('|').map((s) => s.trim()).toList();
      if (cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      if (cells.isNotEmpty &&
          cells.every((s) => RegExp(r'^[:\-\s]+$').hasMatch(s))) {
        continue;
      }
      if (cells.length >= 4 &&
          cells[0].toLowerCase().replaceAll('_', ' ') == 'meal time' &&
          cells[2].toLowerCase().contains('calories')) {
        continue;
      }
      if (cells.length != 4 && cells.length != 6) throw _invalid;
      final time = cells[0].replaceAll('**', '').trim();
      final name = cells[1].replaceAll('**', '').trim();
      const times = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
      final matched = times.where((t) => t.toLowerCase() == time.toLowerCase());
      final kcal = RegExp(r'^(\d+)(?:\s*kcal)?$', caseSensitive: false)
          .firstMatch(cells[2]);
      if (matched.isEmpty || name.isEmpty || kcal == null) throw _invalid;
      final calories = int.tryParse(kcal[1]!);
      if (calories == null || calories <= 0) throw _invalid;
      result.add(MealSuggestion(
          mealTime: matched.first,
          name: name,
          calories: calories,
          protein: _grams(cells[3], 'protein'),
          carbs: cells.length == 6 ? _grams(cells[4], 'carbs') : null,
          fat: cells.length == 6 ? _grams(cells[5], 'fat') : null));
    }
    if (result.length != 4 ||
        result.map((m) => m.mealTime).toSet().length != 4) {
      throw _invalid;
    }
    return List.unmodifiable(result);
  }

  static double _grams(String source, String nutrient) {
    final match = RegExp('^(\\d+(?:\\.\\d+)?)(?:\\s*g)?(?:\\s*$nutrient)?\$',
            caseSensitive: false)
        .firstMatch(source);
    final value = match == null ? null : double.tryParse(match[1]!);
    if (value == null || !value.isFinite || value < 0) throw _invalid;
    return value;
  }

  static const _invalid = MealGenerationException(
      'Allen returned an incomplete or unreadable meal plan. Please try generating it again.');
}
