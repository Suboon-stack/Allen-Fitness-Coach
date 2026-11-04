import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/nutrition_planner_tab.dart'
    show NutritionFeedback;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class MealEntrySheet extends StatefulWidget {
  const MealEntrySheet(
      {super.key, required this.repository, required this.userId});
  final MealRepository repository;
  final String userId;
  @override
  State<MealEntrySheet> createState() => _MealEntrySheetState();
}

class _MealEntrySheetState extends State<MealEntrySheet> {
  final _form = GlobalKey<FormState>();
  final _id = const Uuid().v4();
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  String _mealTime = 'Breakfast';
  bool _saving = false;
  bool _attempted = false;
  DateTime? _createdAt;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (context.read<AuthCubit>().currentUser?.uid != widget.userId) {
      setState(() =>
          _error = 'Your session changed. Close this form and sign in again.');
      return;
    }
    final retry = _attempted;
    _attempted = true;
    final now = DateTime.now();
    _createdAt ??= now;
    final meal = Meal(
        id: _id,
        userId: widget.userId,
        name: _name.text.trim(),
        mealTime: _mealTime,
        calories: int.parse(_calories.text.trim()),
        protein: double.parse(_protein.text.trim()),
        carbs: double.parse(_carbs.text.trim()),
        fat: double.parse(_fat.text.trim()),
        date: now,
        createdAt: _createdAt!);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createMeal(meal);
      // A previous attempt may have reached disk without confirmation. Keep its
      // stable UUID, and confirm any edits made before retrying against that ID.
      if (retry) await widget.repository.updateMeal(meal);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is MealStorageException
              ? error.message
              : 'The meal save couldn’t be confirmed. Your values are kept; please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: AppLayout.formWidth),
                          child: Form(
                              key: _form,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text('Add a meal',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    const SizedBox(height: AppSpacing.sm),
                                    const Text(
                                        'Record what you ate today. Enter the nutrition values for your portion.'),
                                    const SizedBox(height: AppSpacing.lg),
                                    DropdownButtonFormField<String>(
                                        key: const Key('entry-meal-type'),
                                        initialValue: _mealTime,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                            labelText: 'Meal type'),
                                        items: [
                                          for (final time in [
                                            'Breakfast',
                                            'Lunch',
                                            'Dinner',
                                            'Snack'
                                          ])
                                            DropdownMenuItem(
                                                value: time, child: Text(time))
                                        ],
                                        onChanged: _saving
                                            ? null
                                            : (v) {
                                                if (v != null) {
                                                  setState(() => _mealTime = v);
                                                }
                                              }),
                                    const SizedBox(height: AppSpacing.md),
                                    TextFormField(
                                        key: const Key('entry-meal-name'),
                                        controller: _name,
                                        enabled: !_saving,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                            labelText: 'Meal name'),
                                        validator: (v) =>
                                            v == null || v.trim().isEmpty
                                                ? 'Enter a meal name.'
                                                : null),
                                    for (final entry in [
                                      ('Calories (kcal)', _calories),
                                      ('Protein (g)', _protein),
                                      ('Carbohydrates (g)', _carbs),
                                      ('Fat (g)', _fat)
                                    ]) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      TextFormField(
                                          key: ValueKey('entry-${entry.$1}'),
                                          controller: entry.$2,
                                          enabled: !_saving,
                                          decoration: InputDecoration(
                                              labelText: entry.$1),
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                  decimal:
                                                      entry.$2 != _calories),
                                          textInputAction: entry.$2 == _fat
                                              ? TextInputAction.done
                                              : TextInputAction.next,
                                          validator: (v) {
                                            final text = v?.trim() ?? '';
                                            if (entry.$2 == _calories) {
                                              final n = int.tryParse(text);
                                              return n == null || n < 0
                                                  ? 'Enter whole calories, 0 or more.'
                                                  : null;
                                            }
                                            final n = double.tryParse(text);
                                            return n == null ||
                                                    !n.isFinite ||
                                                    n < 0
                                                ? 'Enter grams, 0 or more.'
                                                : null;
                                          }),
                                    ],
                                    if (_error != null)
                                      NutritionFeedback(_error!),
                                    const SizedBox(height: AppSpacing.lg),
                                    FilledButton(
                                        onPressed: _saving ? null : _save,
                                        child: Text(_saving
                                            ? 'Saving meal…'
                                            : 'Save meal')),
                                    TextButton(
                                        onPressed: _saving
                                            ? null
                                            : () => Navigator.of(context)
                                                .pop(false),
                                        child: const Text('Cancel')),
                                  ]))))))));
}
