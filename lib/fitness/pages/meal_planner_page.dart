import '../widgets/feature_navigation.dart';
import 'dart:async';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/models/food_estimate.dart';
import 'package:allen/fitness/models/nutrition_tracker_data.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/meal_entry_sheet.dart';
import 'package:allen/fitness/widgets/nutrition_planner_tab.dart';
import 'package:allen/fitness/widgets/tracker_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MealPlannerPage extends StatefulWidget {
  const MealPlannerPage(
      {super.key, this.aiService, this.repository, this.progressRepository});
  final AiService? aiService;
  final MealRepository? repository;
  final ProgressRepository? progressRepository;
  @override
  State<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends State<MealPlannerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _meals = widget.repository ?? MealRepository();
  late final _progress = widget.progressRepository ?? ProgressRepository();
  late final _ai = widget.aiService ?? AiService();
  final _local = LocalStorageService();
  late final TabController _tabs;
  Timer? _midnight;
  List<Meal> _todayMeals = [];
  NutritionTotals? _totals;
  NutritionGoals _goals = const NutritionGoals();
  bool _goalReadFailed = false;
  bool _nutritionLoading = true,
      _waterLoading = true,
      _waterSaving = false,
      _openingMeal = false;
  String? _nutritionError, _waterError, _observedUser, _nutritionDay, _waterDay;
  int? _water;
  int _nutritionRequest = 0, _waterRequest = 0;
  static const _defaultWaterGoal = 2000.0;

  String _day() => DateTime.now().toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observedUser = context.read<AuthCubit>().currentUser?.uid;
    _tabs = TabController(length: 3, vsync: this)..addListener(_checkDay);
    _refresh();
    _scheduleMidnight();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _tabs.removeListener(_checkDay);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _scheduleMidnight();
    }
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () {
      if (mounted) {
        _refresh();
        _scheduleMidnight();
      }
    });
  }

  void _checkDay() {
    if (_nutritionDay != null &&
        _nutritionDay != _day() &&
        !_nutritionLoading) {
      _loadNutrition();
    }
    if (_waterDay != null && _waterDay != _day() && !_waterLoading) {
      _loadWater();
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadNutrition(), _loadWater()]);
  }

  Future<void> _loadNutrition() async {
    final user = context.read<AuthCubit>().currentUser;
    final request = ++_nutritionRequest;
    final date = DateTime.now(), day = _day();
    setState(() {
      _nutritionLoading = true;
      _nutritionError = null;
    });
    if (user == null) {
      setState(() {
        _nutritionLoading = false;
        _nutritionError = 'Sign in to view your nutrition.';
        _totals = null;
        _todayMeals = [];
      });
      return;
    }
    try {
      // One cached list drives both the ring/macros and today's meals.
      final meals = await _meals.getMealsByDate(user.uid, date);
      final totals = NutritionTotals.fromMeals(meals);
      var goals = const NutritionGoals();
      var failedGoals = false;
      try {
        goals = NutritionGoals.fromStoredProfile(
            await _local.getUserProfile(userId: user.uid), user.uid);
      } catch (_) {
        failedGoals = true;
      }
      if (!mounted ||
          request != _nutritionRequest ||
          context.read<AuthCubit>().currentUser?.uid != user.uid) {
        return;
      }
      if (day != _day()) {
        unawaited(_loadNutrition());
        return;
      }
      setState(() {
        _todayMeals = meals;
        _totals = totals;
        _goals = goals;
        _goalReadFailed = failedGoals;
        _nutritionLoading = false;
        _nutritionDay = day;
      });
    } catch (error) {
      if (!mounted || request != _nutritionRequest) return;
      setState(() {
        _nutritionLoading = false;
        _nutritionError = error is MealStorageException
            ? error.message
            : 'Today’s nutrition couldn’t be loaded. Please retry.';
      });
    }
  }

  Future<void> _loadWater() async {
    final user = context.read<AuthCubit>().currentUser;
    final request = ++_waterRequest;
    final day = _day();
    setState(() {
      _waterLoading = true;
      _waterError = null;
    });
    if (user == null) {
      setState(() {
        _waterLoading = false;
        _waterError = 'Sign in to view water tracking.';
        _water = null;
      });
      return;
    }
    try {
      final water = await _progress.getTodayWaterIntake(user.uid);
      if (water < 0) throw const FormatException('Invalid water total');
      if (!mounted ||
          request != _waterRequest ||
          context.read<AuthCubit>().currentUser?.uid != user.uid) {
        return;
      }
      if (day != _day()) {
        unawaited(_loadWater());
        return;
      }
      setState(() {
        _water = water;
        _waterLoading = false;
        _waterDay = day;
      });
    } catch (error) {
      if (!mounted || request != _waterRequest) return;
      setState(() {
        _waterLoading = false;
        _waterError = error is WaterStorageException
            ? error.message
            : 'Today’s water couldn’t be loaded. Please refresh.';
      });
    }
  }

  Future<void> _openMeal(BuildContext themedContext) async {
    if (_openingMeal) return;
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;
    setState(() => _openingMeal = true);
    final saved = await showModalBottomSheet<bool>(
        context: themedContext,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => MealEntrySheet(repository: _meals, userId: user.uid));
    if (!mounted) return;
    setState(() => _openingMeal = false);
    if (saved == true) {
      await _loadNutrition();
      if (mounted) {
        _notify(_nutritionError == null
            ? 'Meal saved.'
            : 'Meal saved. Refresh to update your totals.');
      }
    }
  }

  Future<void> _addWater(int amount) async {
    if (_waterSaving || _waterLoading || _waterError != null) return;
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;
    setState(() => _waterSaving = true);
    try {
      await _progress.addWaterIntake(user.uid, amount);
      if (!mounted) return;
      await _loadWater();
      if (mounted) {
        _notify(_waterError == null
            ? 'Added $amount ml.'
            : 'Water logged. Refresh to see your total.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _waterError = error is WaterStorageException
            ? error.message
            : 'Water save couldn’t be confirmed. Refresh your total before adding again.');
      }
    } finally {
      if (mounted) setState(() => _waterSaving = false);
    }
  }

  void _notify(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        final uid = context.read<AuthCubit>().currentUser?.uid;
        if (uid != _observedUser) {
          _observedUser = uid;
          _refresh();
        }
      },
      child: AppThemeScope(
          child: Builder(
              builder: (context) => PopScope(
                  canPop: !_waterSaving,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && _waterSaving) {
                      _notify('Finishing your water update…');
                    }
                  },
                  child: Scaffold(
                    appBar: AppBar(
                        title: const Text('Nutrition'),
                        bottom: TabBar(controller: _tabs, tabs: const [
                          Tab(text: 'Tracker'),
                          Tab(text: 'Planner'),
                          Tab(text: 'Water')
                        ])),
                    bottomNavigationBar:
                        FeatureNavigation(index: 2, onReturn: _refresh),
                    body: SafeArea(
                        top: false,
                        child: TabBarView(controller: _tabs, children: [
                          _tracker(context),
                          NutritionPlannerTab(
                              aiService: _ai,
                              repository: _meals,
                              onLogged: _loadNutrition,
                              // Planner preference is not a configured profile goal.
                              onTargetChanged: (_) {}),
                          _waterTracker(context),
                        ])),
                  )))));

  Widget _page(
          {required Future<void> Function() onRefresh,
          required List<Widget> children}) =>
      RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: AppLayout.contentWidth),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children)))
              ]));

  Widget _heading(BuildContext context, String text, VoidCallback? refresh) =>
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Text(text, style: Theme.of(context).textTheme.titleLarge),
            TextButton(onPressed: refresh, child: const Text('Refresh'))
          ]);

  Widget _tracker(BuildContext context) {
    final theme = Theme.of(context);
    final totals = _totals;
    return _page(onRefresh: _loadNutrition, children: [
      _heading(context, 'Today’s nutrition',
          _nutritionLoading ? null : _loadNutrition),
      const SizedBox(height: AppSpacing.md),
      if (_nutritionLoading)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: LinearProgressIndicator(
                semanticsLabel: 'Loading recorded nutrition'))
      else if (_nutritionError != null)
        NutritionFeedback(_nutritionError!, onRetry: _loadNutrition)
      else if (totals != null) ...[
        TrackerProgress(
            key: const Key('calorie-progress'),
            value: totals.calories.toDouble(),
            unit: 'kcal',
            semanticName: 'Calories',
            centerIcon: const NutritionAppleIcon(),
            goal: _goals.calories,
            goalLabel: 'Saved calorie goal',
            noGoalLabel: _goalReadFailed
                ? 'Calorie goal unavailable.'
                : 'No calorie goal configured.'),
        const SizedBox(height: AppSpacing.lg),
        _macros(context, totals),
        if (_goalReadFailed)
          const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                  'Saved goals couldn’t be read. Recorded meal totals are shown.')),
      ],
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
          onPressed:
              _openingMeal || context.read<AuthCubit>().currentUser == null
                  ? null
                  : () => _openMeal(context),
          child: const Text('Add Meal')),
      const SizedBox(height: AppSpacing.xl),
      Text('Today’s meals', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      if (!_nutritionLoading && _nutritionError == null) ...[
        if (_todayMeals.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No meals recorded today.'),
                    SizedBox(height: AppSpacing.sm),
                    Text('Add a meal to start tracking your nutrition.'),
                  ])),
        for (var i = 0; i < _todayMeals.length; i++) ...[
          if (i > 0) const Divider(),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_todayMeals[i].mealTime,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.secondary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_todayMeals[i].name,
                        style: theme.textTheme.titleMedium),
                    if (_todayMeals[i]
                            .notes
                            ?.startsWith(FoodEstimate.notePrefix) ??
                        false)
                      Text('AI Estimate · reviewed',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.secondary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                        '${trackerNumber(_todayMeals[i].calories)} kcal · ${trackerNumber(_todayMeals[i].protein)} g protein'),
                    Text(
                        '${trackerNumber(_todayMeals[i].carbs)} g carbs · ${trackerNumber(_todayMeals[i].fat)} g fat',
                        style: theme.textTheme.bodySmall),
                  ])),
        ],
      ],
    ]);
  }

  Widget _macros(BuildContext context, NutritionTotals totals) => Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.panel)),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = MediaQuery.textScalerOf(context).scale(14) > 21 ? 1 : 3;
        final width =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.lg,
            children: [
              for (final macro in [
                ('Protein', totals.protein, _goals.protein),
                ('Carbohydrates', totals.carbs, _goals.carbs),
                ('Fat', totals.fat, _goals.fat)
              ])
                SizedBox(
                    width: width,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(macro.$1,
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: AppSpacing.xs),
                          Text('${trackerNumber(macro.$2)} g',
                              style: Theme.of(context).textTheme.titleMedium),
                          if (macro.$3 != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text('Goal ${trackerNumber(macro.$3!)} g',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(
                                '${trackerNumber(macro.$2 / macro.$3! * 100)}% of goal',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary)),
                          ],
                        ])),
            ]);
      }));

  Widget _waterTracker(BuildContext context) => _page(
          onRefresh: () async {
            if (!_waterSaving) await _loadWater();
          },
          children: [
            _heading(context, 'Today’s hydration',
                _waterSaving || _waterLoading ? null : _loadWater),
            const SizedBox(height: AppSpacing.md),
            if (_waterLoading)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: LinearProgressIndicator(
                      semanticsLabel: 'Loading recorded water'))
            else if (_waterError != null)
              NutritionFeedback(_waterError!,
                  onRetry: _waterSaving ? null : _loadWater)
            else if (_water != null)
              TrackerProgress(
                  key: const Key('water-progress'),
                  value: _water!.toDouble(),
                  unit: 'ml',
                  semanticName: 'Water',
                  centerIcon: const Icon(Icons.water_drop_outlined),
                  goal: _defaultWaterGoal,
                  goalLabel: 'App default goal'),
            const SizedBox(height: AppSpacing.lg),
            Text('Add water', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              for (final amount in [100, 250, 500])
                FilledButton(
                    onPressed:
                        _waterSaving || _waterLoading || _waterError != null
                            ? null
                            : () => _addWater(amount),
                    child: Text('+$amount ml')),
            ]),
            if (_waterSaving)
              Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Semantics(
                      liveRegion: true, child: const Text('Saving water…'))),
            const SizedBox(height: AppSpacing.lg),
            const Text(
                'The 2,000 ml app default is not a personalized recommendation.'),
            const SizedBox(height: AppSpacing.sm),
            Text('Individual water entries and undo are not available.',
                style: Theme.of(context).textTheme.bodySmall),
          ]);
}
