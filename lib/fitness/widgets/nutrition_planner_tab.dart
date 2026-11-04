import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/meal_plan_parser.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class NutritionFeedback extends StatelessWidget {
  const NutritionFeedback(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
        liveRegion: true,
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(AppRadii.panel)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message, style: TextStyle(color: colors.onErrorContainer)),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Try again')),
            ])));
  }
}

class NutritionPlannerTab extends StatefulWidget {
  const NutritionPlannerTab(
      {super.key,
      required this.aiService,
      required this.repository,
      required this.onLogged,
      required this.onTargetChanged});
  final AiService aiService;
  final MealRepository repository;
  final Future<void> Function() onLogged;
  final ValueChanged<int> onTargetChanged;
  @override
  State<NutritionPlannerTab> createState() => _NutritionPlannerTabState();
}

class _NutritionPlannerTabState extends State<NutritionPlannerTab>
    with AutomaticKeepAliveClientMixin {
  String _goal = 'Lose Weight';
  String _diet = 'No preference';
  int _calories = 2000;
  bool _loading = false;
  bool _reviewing = false;
  String? _error;
  String? _planSummary;
  String? _owner;
  List<MealSuggestion> _meals = [];
  List<String> _ids = [];
  final Set<int> _logged = {};
  @override
  bool get wantKeepAlive => true;

  Future<void> _generate() async {
    if (_loading || _reviewing) return;
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) {
      setState(() => _error = 'Sign in before generating meal suggestions.');
      return;
    }
    final goal = _goal, diet = _diet;
    final calories = _calories;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final source = await widget.aiService
          .generateMealPlan(goal: goal, diet: diet, calories: calories);
      final meals = MealPlanParser.parse(source);
      if (!mounted) return;
      if (context.read<AuthCubit>().currentUser?.uid != user.uid) return;
      setState(() {
        _meals = meals;
        _ids = meals.map((_) => const Uuid().v4()).toList();
        _owner = user.uid;
        _logged.clear();
        _planSummary = '$goal · $diet · requested $calories kcal';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is MealGenerationException
            ? error.message
            : 'Meal suggestions couldn’t be generated. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(int index) async {
    if (_loading || _reviewing || _logged.contains(index)) return;
    final user = context.read<AuthCubit>().currentUser;
    if (user == null || user.uid != _owner) {
      setState(() => _error =
          'Your session changed. Generate suggestions again before logging.');
      return;
    }
    setState(() => _reviewing = true);
    final logged = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _MealReview(
            suggestion: _meals[index],
            id: _ids[index],
            userId: user.uid,
            repository: widget.repository));
    if (!mounted) return;
    setState(() {
      _reviewing = false;
      if (logged == true) _logged.add(index);
    });
    if (logged == true) {
      // The write is already confirmed. Refresh failure must not invite a second log.
      await widget.onLogged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal logged for today.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final user = context.watch<AuthCubit>().currentUser;
    final showMeals = _meals.isNotEmpty && _owner == user?.uid;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppLayout.contentWidth),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Plan your meals',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                          'Suggestions for your day. Review a meal before logging it.'),
                      const SizedBox(height: AppSpacing.lg),
                      if (showMeals)
                        ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            shape: const Border(),
                            collapsedShape: const Border(),
                            title: const Text('Meal preferences'),
                            children: [_preferences(context)])
                      else
                        _preferences(context),
                      if (_error != null) NutritionFeedback(_error!),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                          onPressed: _loading || _reviewing ? null : _generate,
                          child: Text(_loading
                              ? 'Planning your meals…'
                              : _error != null
                                  ? 'Try generating again'
                                  : showMeals
                                      ? 'Generate another plan'
                                      : 'Generate meal plan')),
                      if (_loading)
                        const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.md),
                            child: LinearProgressIndicator(
                                semanticsLabel: 'Generating meal suggestions')),
                      if (showMeals) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text('Your suggestions',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Text(_planSummary!, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                            'Suggested total · ${_meals.fold<int>(0, (sum, meal) => sum + meal.calories)} kcal',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                            'AI nutrition estimates. Confirm portions and values before logging. Suggestions are not recorded intake.'),
                        const SizedBox(height: AppSpacing.md),
                        for (var i = 0; i < _meals.length; i++) ...[
                          if (i > 0) const Divider(),
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_meals[i].mealTime,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                                color: theme
                                                    .colorScheme.secondary)),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(_meals[i].name,
                                        style: theme.textTheme.titleMedium),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                        '${_meals[i].calories} kcal · ${_meals[i].protein} g protein'),
                                    Text(_meals[i].carbs == null
                                        ? 'Carbs and fat need confirmation'
                                        : '${_meals[i].carbs} g carbs · ${_meals[i].fat} g fat'),
                                    const SizedBox(height: AppSpacing.sm),
                                    OutlinedButton(
                                        onPressed: _loading ||
                                                _reviewing ||
                                                _logged.contains(i)
                                            ? null
                                            : () => _review(i),
                                        child: Text(_logged.contains(i)
                                            ? 'Logged today'
                                            : 'Review & log meal')),
                                  ])),
                        ],
                      ],
                    ]))));
  }

  Widget _preferences(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, constraints) {
          final goal = _dropdown(
              'Meal goal',
              _goal,
              ['Lose Weight', 'Gain Muscle', 'Maintain'],
              (v) => setState(() => _goal = v));
          final diet = _dropdown(
              'Diet preference',
              _diet,
              [
                'No preference',
                'Vegetarian',
                'Vegan',
                'High Protein',
                'Low Carb'
              ],
              (v) => setState(() => _diet = v));
          return constraints.maxWidth > 500 &&
                  MediaQuery.textScalerOf(context).scale(16) <= 24
              ? Row(children: [
                  Expanded(child: goal),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: diet)
                ])
              : Column(children: [
                  goal,
                  const SizedBox(height: AppSpacing.md),
                  diet
                ]);
        }),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<int>(
            key: const Key('meal-calorie-target'),
            initialValue: _calories,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Daily calorie preference'),
            items: [
              for (var value = 1200; value <= 4000; value += 100)
                DropdownMenuItem(value: value, child: Text('$value kcal'))
            ],
            onChanged: _loading || _reviewing
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _calories = value);
                      widget.onTargetChanged(value);
                    }
                  }),
        const SizedBox(height: AppSpacing.sm),
        Text(
            'Planning preference, not a personalized nutrition recommendation.',
            style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _dropdown(String label, String value, List<String> options,
          ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
          key: ValueKey(label),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: options
              .map((option) =>
                  DropdownMenuItem(value: option, child: Text(option)))
              .toList(),
          onChanged: _loading || _reviewing
              ? null
              : (v) {
                  if (v != null) onChanged(v);
                });
}

class _MealReview extends StatefulWidget {
  const _MealReview(
      {required this.suggestion,
      required this.id,
      required this.userId,
      required this.repository});
  final MealSuggestion suggestion;
  final String id;
  final String userId;
  final MealRepository repository;
  @override
  State<_MealReview> createState() => _MealReviewState();
}

class _MealReviewState extends State<_MealReview> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.suggestion.name);
  late final _calories =
      TextEditingController(text: '${widget.suggestion.calories}');
  late final _protein =
      TextEditingController(text: '${widget.suggestion.protein}');
  late final _carbs =
      TextEditingController(text: widget.suggestion.carbs?.toString() ?? '');
  late final _fat =
      TextEditingController(text: widget.suggestion.fat?.toString() ?? '');
  bool _saving = false;
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      await widget.repository.createMeal(Meal(
          id: widget.id,
          userId: widget.userId,
          name: _name.text.trim(),
          mealTime: widget.suggestion.mealTime,
          calories: int.parse(_calories.text.trim()),
          protein: double.parse(_protein.text.trim()),
          carbs: double.parse(_carbs.text.trim()),
          fat: double.parse(_fat.text.trim()),
          date: now,
          createdAt: now,
          notes: 'AI suggestion reviewed before logging.'));
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is MealStorageException
              ? error.message
              : 'The meal save couldn’t be confirmed. Please retry.';
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
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                        'Review ${widget.suggestion.mealTime.toLowerCase()}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    const SizedBox(height: AppSpacing.sm),
                                    const Text(
                                        'Log only what you ate today. Adjust these estimates to match your portion. All nutrition fields need confirmation.'),
                                    const SizedBox(height: AppSpacing.lg),
                                    TextFormField(
                                        key: const Key('review-meal-name'),
                                        controller: _name,
                                        enabled: !_saving,
                                        decoration: const InputDecoration(
                                            labelText: 'Meal name'),
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        validator: (v) =>
                                            v == null || v.trim().isEmpty
                                                ? 'Enter a meal name.'
                                                : null),
                                    for (final entry in [
                                      ('Calories (kcal)', _calories),
                                      ('Protein (g)', _protein),
                                      ('Carbs (g)', _carbs),
                                      ('Fat (g)', _fat)
                                    ]) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      TextFormField(
                                          key: ValueKey('review-${entry.$1}'),
                                          controller: entry.$2,
                                          enabled: !_saving,
                                          decoration: InputDecoration(
                                              labelText: entry.$1),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          validator: (v) {
                                            final text = v?.trim() ?? '';
                                            if (entry.$2 == _calories) {
                                              final n = int.tryParse(text);
                                              return n == null || n <= 0
                                                  ? 'Enter a positive whole calorie value.'
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
                                            ? 'Logging meal…'
                                            : 'Log meal for today')),
                                    TextButton(
                                        onPressed: _saving
                                            ? null
                                            : () => Navigator.of(context)
                                                .pop(false),
                                        child: const Text('Cancel')),
                                  ]))))))));
}
