import 'dart:convert';

enum FoodScanFailure {
  image,
  network,
  timeout,
  rateLimited,
  unavailable,
  configuration,
  blocked,
  unidentifiable,
  malformed,
  truncated,
  busy,
  cancelled
}

/// Fixed app-owned messages only; provider diagnostics never cross into UI.
class FoodScanException implements Exception {
  const FoodScanException(this.failure);
  final FoodScanFailure failure;
  String get message => switch (failure) {
        FoodScanFailure.image =>
          'Choose a JPEG, PNG, or WebP photo under 8 MB. Try another image if this one can’t be read.',
        FoodScanFailure.network =>
          'Couldn’t connect. Check your connection and retry.',
        FoodScanFailure.timeout => 'The analysis took too long. Please retry.',
        FoodScanFailure.rateLimited =>
          'The AI request limit has been reached. Wait a moment, then retry.',
        FoodScanFailure.configuration =>
          'Food analysis can’t connect to the AI service right now. Try again later.',
        FoodScanFailure.blocked =>
          'This photo couldn’t be analyzed. Try a clear photo of your food.',
        FoodScanFailure.unidentifiable =>
          'No food could be identified. Try a clear, well-lit photo of the full portion.',
        FoodScanFailure.malformed =>
          'Allen couldn’t read a complete nutrition estimate. Retry or choose another photo.',
        FoodScanFailure.truncated =>
          'The nutrition estimate was cut short. Please retry.',
        FoodScanFailure.busy => 'Wait for the current analysis to finish.',
        FoodScanFailure.cancelled => 'This analysis is no longer active.',
        FoodScanFailure.unavailable =>
          'Food analysis is unavailable right now. Please retry shortly.',
      };
  @override
  String toString() => message;
}

class IdentifiedFood {
  const IdentifiedFood({required this.name, this.portion});
  final String name;
  final String? portion;
}

/// Transient review model, not a new persistence schema. Nutrition is for the
/// entire photographed portion, never inferred from a missing model field.
class FoodEstimate {
  FoodEstimate(
      {required this.name,
      required this.calories,
      required this.protein,
      required this.carbs,
      required this.fat,
      this.portion,
      this.tip,
      List<IdentifiedFood> items = const []})
      : items = List.unmodifiable(items);
  final String name;
  final int calories;
  final double protein, carbs, fat;
  final String? portion;
  final String? tip;
  final List<IdentifiedFood> items;
  static const notePrefix = 'AI photo estimate — reviewed by user.';
  String get nutritionNotes => [
        notePrefix,
        if (portion != null) 'Portion: $portion',
        for (final item in items)
          '${item.name}${item.portion == null ? '' : ' (${item.portion})'}',
        if (tip != null) 'AI note: $tip',
      ].join('\n');

  static FoodEstimate parse(String text) {
    try {
      if (text.length > 20000) throw const FormatException();
      final data = jsonDecode(text);
      if (data is! Map) throw const FormatException();
      if (data['unidentifiable'] == true) {
        throw const FoodScanException(FoodScanFailure.unidentifiable);
      }
      String label(dynamic value, {int max = 200}) {
        if (value is! String ||
            value.trim().isEmpty ||
            value.length > max ||
            value.contains(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'))) {
          throw const FormatException();
        }
        return value.trim();
      }

      String? portion(dynamic value) => value == null ? null : label(value);
      double grams(dynamic value) {
        if (value is! num || !value.isFinite || value < 0) {
          throw const FormatException();
        }
        return value.toDouble();
      }

      final calories = data['calories'];
      if (calories is! int || calories < 0) throw const FormatException();
      final rawItems = data['items'];
      if (rawItems != null && (rawItems is! List || rawItems.length > 20)) {
        throw const FormatException();
      }
      final items = <IdentifiedFood>[];
      for (final item in (rawItems as List? ?? [])) {
        if (item is! Map) throw const FormatException();
        items.add(IdentifiedFood(
            name: label(item['name']), portion: portion(item['portion'])));
      }
      return FoodEstimate(
          name: label(data['foodName']),
          calories: calories,
          protein: grams(data['protein']),
          carbs: grams(data['carbs']),
          fat: grams(data['fat']),
          portion: portion(data['portion']),
          tip: data['tip'] == null ? null : label(data['tip'], max: 400),
          items: items);
    } on FoodScanException {
      rethrow;
    } catch (_) {
      throw const FoodScanException(FoodScanFailure.malformed);
    }
  }
}
