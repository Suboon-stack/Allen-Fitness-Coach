import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/food_estimate.dart';
import '../models/meal_model.dart';
import '../repositories/meal_repository.dart';
import '../services/ai_service.dart';

/// Transient image/review state. A stable UUID makes uncertain save retries
/// idempotent without changing MealRepository or the on-disk schema.
class FoodScannerController extends ChangeNotifier {
  FoodScannerController(
      {required AiService service,
      required this.repository,
      required this.currentUser})
      : _service = service,
        _user = currentUser();
  final AiService _service;
  final MealRepository repository;
  final String? Function() currentUser;
  String? _user;
  String? get userId => _user;
  File? image;
  FoodEstimate? estimate;
  String? error;
  bool analyzing = false, saving = false, saved = false;
  bool _closed = false, _attempted = false;
  int _generation = 0;
  String _mealId = const Uuid().v4();
  DateTime? _savedDate;
  bool get busy => analyzing || saving;
  bool get active => !_closed && _user != null && _user == currentUser();

  void syncUser() {
    if (_closed || _user == currentUser()) return;
    _generation++;
    _user = currentUser();
    _service.cancelFoodAnalysis();
    image = null;
    estimate = null;
    error = null;
    analyzing = false;
    saving = false;
    saved = false;
    _newDraft();
    notifyListeners();
  }

  void _newDraft() {
    _mealId = const Uuid().v4();
    _savedDate = null;
    _attempted = false;
  }

  bool select(File file) {
    syncUser();
    if (!active || busy) return false;
    _generation++;
    image = file;
    estimate = null;
    error = null;
    saved = false;
    _newDraft();
    notifyListeners();
    return true;
  }

  void clear() {
    if (_closed || saving) return;
    _generation++;
    _service.cancelFoodAnalysis();
    image = null;
    estimate = null;
    error = null;
    analyzing = false;
    saved = false;
    _newDraft();
    notifyListeners();
  }

  Future<void> analyze() async {
    syncUser();
    if (!active || image == null || busy || saved || estimate != null) return;
    final generation = ++_generation, owner = _user;
    final file = image!;
    bool current() => active && generation == _generation && owner == _user;
    analyzing = true;
    error = null;
    notifyListeners();
    try {
      final value = await _service.analyzeFoodEstimate(file);
      if (!current()) return;
      estimate = value;
    } catch (failure) {
      if (!current()) return;
      error = failure is FoodScanException
          ? failure.message
          : const FoodScanException(FoodScanFailure.unavailable).message;
    } finally {
      if (current()) {
        analyzing = false;
        notifyListeners();
      }
    }
  }

  void edit(FoodEstimate value) {
    syncUser();
    if (!active || busy || saved || estimate == null) return;
    estimate = value;
    error = null;
    notifyListeners();
  }

  Future<bool> save({required String mealTime}) async {
    syncUser();
    if (!active ||
        busy ||
        saved ||
        estimate == null ||
        !['Breakfast', 'Lunch', 'Dinner', 'Snack'].contains(mealTime)) {
      return false;
    }
    final generation = ++_generation, owner = _user!, value = estimate!;
    bool current() => active && generation == _generation && owner == _user;
    saving = true;
    error = null;
    _savedDate ??= DateTime.now();
    final retry = _attempted;
    _attempted = true;
    final meal = Meal(
        id: _mealId,
        userId: owner,
        name: value.name,
        mealTime: mealTime,
        calories: value.calories,
        protein: value.protein,
        carbs: value.carbs,
        fat: value.fat,
        date: _savedDate!,
        createdAt: _savedDate!,
        notes: value.nutritionNotes);
    notifyListeners();
    try {
      if (!current()) return false;
      await repository.createMeal(meal);
      // A native write may have succeeded before a lost acknowledgment. Retain
      // its ID/date and reconcile subsequent reviewed edits on retry.
      if (!current()) return false;
      if (retry) await repository.updateMeal(meal);
      if (!current()) return false;
      saved = true;
      return true;
    } catch (_) {
      if (current()) {
        error =
            'The save couldn’t be confirmed. Your reviewed values are kept. Please retry.';
      }
      return false;
    } finally {
      if (current()) {
        saving = false;
        notifyListeners();
      }
    }
  }

  void abandon() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _service.cancelFoodAnalysis();
  }

  @override
  void dispose() {
    abandon();
    super.dispose();
  }
}
