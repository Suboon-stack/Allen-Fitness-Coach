import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/workout_model.dart';
import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/workout_plan_parser.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/workout_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, this.aiService, this.repository});
  final AiService? aiService;
  final WorkoutRepository? repository;
  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage>
    with SingleTickerProviderStateMixin {
  late final AiService _ai = widget.aiService ?? AiService();
  late final WorkoutRepository _repo = widget.repository ?? WorkoutRepository();
  late final TabController _tabs;
  int _visibleTab = 0;
  String _focus = 'Chest';
  String _level = 'Intermediate';
  int _duration = 45;
  String _filter = 'All';
  Workout? _draft;
  String? _savedId;
  bool _completed = false;
  bool _generating = false;
  String? _mutatingId;
  String? _generationError;
  String? _planError;
  String? _historyError;
  String? _historyActionError;
  bool _historyLoading = true;
  List<Workout> _history = [];
  int _historyRequest = 0;
  bool get _busy => _generating || _mutatingId != null;
  static const _focusOptions = [
    'Chest',
    'Back',
    'Legs',
    'Arms',
    'Shoulders',
    'Core',
    'Full Body'
  ];
  static const _levels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(_tabChanged);
    _reloadHistory();
  }

  void _tabChanged() {
    if (_tabs.index != _visibleTab && mounted) {
      setState(() => _visibleTab = _tabs.index);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reloadHistory() async {
    final user = context.read<AuthCubit>().currentUser;
    final request = ++_historyRequest;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    if (user == null) {
      setState(() {
        _historyLoading = false;
        _historyError = 'Sign in to view your saved workouts.';
      });
      return;
    }
    try {
      final workouts = await _repo.getUserWorkouts(user.uid);
      if (!mounted || request != _historyRequest) return;
      setState(() {
        _history = workouts;
        _historyLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _historyRequest) return;
      setState(() {
        _historyLoading = false;
        _historyError = _message(
            error, 'Saved workouts couldn’t be loaded. Please try again.');
      });
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) {
      setState(() => _generationError = 'Sign in before generating a workout.');
      return;
    }
    final focus = _focus;
    final level = _level;
    final duration = _duration;
    setState(() {
      _generating = true;
      _generationError = null;
    });
    try {
      final source = await _ai.generateWorkout(
          muscleGroup: focus, difficulty: level, duration: '$duration min');
      final plan = WorkoutPlanParser.parse(source);
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _draft = Workout(
            id: const Uuid().v4(),
            userId: user.uid,
            name: '$focus workout',
            muscleGroup: focus,
            difficulty: level,
            durationMinutes: duration,
            exercises: plan.exercises,
            notes: plan.source,
            date: now,
            createdAt: now);
        _savedId = null;
        _completed = false;
        _planError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _generationError = _message(
          error, 'Your workout couldn’t be generated. Please try again.'));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save({bool complete = false}) async {
    final draft = _draft;
    if (_busy ||
        draft == null ||
        (complete && _completed) ||
        (!complete && _savedId != null)) {
      return;
    }
    setState(() {
      _mutatingId = draft.id;
      _planError = null;
    });
    try {
      if (_savedId == null) {
        final id = await _repo.createWorkout(draft);
        if (!mounted) return;
        setState(() => _savedId = id);
      }
      if (complete) {
        await _repo.markWorkoutComplete(_savedId!, true);
        if (!mounted) return;
        setState(() => _completed = true);
      }
      if (!mounted) return;
      _reloadHistory();
      _notify(complete ? 'Workout completed.' : 'Workout saved.');
    } catch (error) {
      if (!mounted) return;
      final fallback = complete && _savedId != null
          ? 'Your workout is saved, but completion failed. Try completing it again.'
          : 'Your workout save couldn’t be confirmed. Please try again.';
      setState(() => _planError = _message(error, fallback));
    } finally {
      if (mounted) setState(() => _mutatingId = null);
    }
  }

  Future<void> _completeSaved(Workout workout) async {
    if (_busy || workout.completed) return;
    setState(() {
      _mutatingId = workout.id;
      _historyActionError = null;
    });
    try {
      await _repo.markWorkoutComplete(workout.id, true);
      if (!mounted) return;
      if (_savedId == workout.id) setState(() => _completed = true);
      await _reloadHistory();
      if (mounted) _notify('Workout completed.');
    } catch (error) {
      if (mounted) {
        setState(() => _historyActionError =
            _message(error, 'Completion couldn’t be saved. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _mutatingId = null);
    }
  }

  Future<void> _delete(Workout workout) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Delete workout?'),
              content: Text(
                  'Delete “${workout.name}” from saved workouts? This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Delete workout')),
              ],
            ));
    if (!mounted || confirmed != true || _busy) return;
    setState(() {
      _mutatingId = workout.id;
      _historyActionError = null;
    });
    try {
      await _repo.deleteWorkout(workout.id);
      if (!mounted) return;
      if (_savedId == workout.id) {
        setState(() {
          _savedId = null;
          _completed = false;
        });
      }
      await _reloadHistory();
      if (mounted) _notify('Workout deleted.');
    } catch (error) {
      if (mounted) {
        setState(() => _historyActionError = _message(
            error, 'The workout couldn’t be deleted. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _mutatingId = null);
    }
  }

  String _message(Object error, String fallback) {
    if (error is WorkoutGenerationException) return error.message;
    if (error is WorkoutStorageException) return error.message;
    return fallback;
  }

  void _notify(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => AppThemeScope(
        child: Builder(builder: _buildPage),
      );

  Widget _buildPage(BuildContext context) => PopScope(
        canPop: _mutatingId == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _mutatingId != null) {
            _notify('Finishing your workout update…');
          }
        },
        child: Scaffold(
          appBar: AppBar(
              title: const Text('Workouts'),
              bottom: TabBar(
                controller: _tabs,
                tabs: const [Tab(text: 'Plan'), Tab(text: 'Saved')],
                labelColor: Theme.of(context).colorScheme.secondary,
              )),
          body: SafeArea(
              top: false,
              child: TabBarView(controller: _tabs, children: [
                _planner(context),
                _savedWorkouts(context),
              ])),
          bottomNavigationBar:
              _draft != null && _visibleTab == 0 ? _saveActions(context) : null,
        ),
      );

  Widget _planner(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _draft;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppLayout.contentWidth),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (draft == null) ...[
                      Text('Build your session',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                          'Choose your focus, level, and available time.'),
                      const SizedBox(height: 24),
                      _preferences(context),
                    ] else ...[
                      Text(draft.name, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                          '${draft.difficulty} · ${draft.durationMinutes} min · ${draft.exercises.length} exercises'),
                      const SizedBox(height: 8),
                      Semantics(
                          liveRegion: true,
                          child: Text(
                              _completed
                                  ? 'Completed'
                                  : _savedId == null
                                      ? 'Not saved yet'
                                      : 'Saved to your workouts',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.secondary))),
                      const SizedBox(height: 12),
                      ExpansionTile(
                          title: const Text('Workout preferences'),
                          tilePadding: EdgeInsets.zero,
                          shape: const Border(),
                          collapsedShape: const Border(),
                          children: [_preferences(context)]),
                      if (_planError != null) WorkoutFeedback(_planError!),
                      const SizedBox(height: 8),
                      WorkoutExerciseList(
                          details: WorkoutPlanParser.detailsFor(draft)),
                    ],
                  ]),
            )));
  }

  Widget _preferences(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 500 &&
              MediaQuery.textScalerOf(context).scale(16) <= 24;
          final focus = DropdownButtonFormField<String>(
            key: const Key('workout-focus'),
            initialValue: _focus,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Focus'),
            items: _focusOptions
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) setState(() => _focus = value);
                  },
          );
          final level = DropdownButtonFormField<String>(
            key: const Key('workout-level'),
            initialValue: _level,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Level'),
            items: _levels
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) setState(() => _level = value);
                  },
          );
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: focus),
                  const SizedBox(width: 16),
                  Expanded(child: level)
                ])
              : Column(children: [focus, const SizedBox(height: 16), level]);
        }),
        const SizedBox(height: 20),
        Text('Time available', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final minutes in [20, 30, 45, 60])
            ChoiceChip(
                label: Text('$minutes min'),
                selected: _duration == minutes,
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected:
                    _busy ? null : (_) => setState(() => _duration = minutes)),
        ]),
        if (_generationError != null) WorkoutFeedback(_generationError!),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: _busy ? null : _generate,
            child: Text(_generating
                ? 'Building your workout…'
                : _generationError != null
                    ? 'Try generating again'
                    : _draft == null
                        ? 'Generate workout'
                        : 'Generate another workout')),
        if (_generating)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(
                  semanticsLabel: 'Generating workout')),
        const SizedBox(height: 16),
      ]);

  Widget _saveActions(BuildContext context) => SafeArea(
      top: false,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppLayout.contentWidth),
                child: LayoutBuilder(builder: (context, constraints) {
                  final two = constraints.maxWidth >= 360 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 20;
                  final width = two
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(spacing: 12, runSpacing: 8, children: [
                    SizedBox(
                        width: width,
                        child: FilledButton(
                            onPressed: _busy || _savedId != null
                                ? null
                                : () => _save(),
                            child: Text(_mutatingId != null && _savedId == null
                                ? 'Saving…'
                                : _savedId == null
                                    ? 'Save workout'
                                    : 'Saved'))),
                    SizedBox(
                        width: width,
                        child: OutlinedButton(
                            onPressed: _busy || _completed
                                ? null
                                : () => _save(complete: true),
                            child: Text(_completed
                                ? 'Completed'
                                : _mutatingId != null && _savedId != null
                                    ? 'Completing…'
                                    : _savedId == null
                                        ? 'Save & complete'
                                        : 'Complete workout'))),
                  ]);
                }))),
      ));

  Widget _savedWorkouts(BuildContext context) {
    final visible = _history
        .where((workout) =>
            _filter == 'All' ||
            (_filter == 'Completed' ? workout.completed : !workout.completed))
        .toList();
    return RefreshIndicator(
        onRefresh: _reloadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Align(
                child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: AppLayout.contentWidth),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Your saved sessions',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                for (final filter in [
                                  'All',
                                  'Ready',
                                  'Completed'
                                ])
                                  ChoiceChip(
                                      label: Text(filter),
                                      showCheckmark: false,
                                      selected: _filter == filter,
                                      onSelected: (_) =>
                                          setState(() => _filter = filter)),
                                TextButton(
                                    onPressed: _historyLoading || _busy
                                        ? null
                                        : _reloadHistory,
                                    child: const Text('Refresh')),
                              ]),
                          if (_historyLoading)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: LinearProgressIndicator(
                                    semanticsLabel: 'Loading saved workouts')),
                          if (_historyError != null)
                            WorkoutFeedback(_historyError!,
                                onRetry:
                                    _historyLoading ? null : _reloadHistory),
                          if (_historyActionError != null)
                            WorkoutFeedback(_historyActionError!),
                          if (!_historyLoading &&
                              _historyError == null &&
                              visible.isEmpty)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 32),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          _history.isEmpty
                                              ? 'No saved workouts yet'
                                              : 'No ${_filter.toLowerCase()} workouts',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: 8),
                                      const Text(
                                          'Generate a session, save it, and come back when you’re ready.'),
                                      const SizedBox(height: 12),
                                      TextButton(
                                          onPressed: () => _tabs.animateTo(0),
                                          child: const Text('Plan a workout')),
                                    ])),
                          if (_history.length == 50)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                    'Showing the latest 50 saved sessions.')),
                          for (final workout in visible)
                            _savedSession(context, workout),
                        ]))),
          ],
        ));
  }

  Widget _savedSession(BuildContext context, Workout workout) {
    final theme = Theme.of(context);
    final date = DateFormat.yMMMd()
        .format(workout.completed ? workout.date : workout.createdAt);
    final sourceNotes = WorkoutPlanParser.restoredPlan(workout);
    return Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant)),
        child: ExpansionTile(
          key: PageStorageKey('saved-${workout.id}'),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(workout.name, style: theme.textTheme.titleMedium),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${workout.difficulty} · ${workout.durationMinutes} min · ${workout.exercises.length} exercises'),
            Text('${workout.completed ? 'Completed' : 'Saved'} $date'),
            Text(workout.completed ? 'Completed' : 'Ready',
                style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600)),
          ]),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            WorkoutExerciseList(details: WorkoutPlanParser.detailsFor(workout)),
            if (sourceNotes == null && workout.notes?.trim().isNotEmpty == true)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(workout.notes!)),
            Wrap(spacing: 12, runSpacing: 8, children: [
              if (!workout.completed)
                OutlinedButton(
                    onPressed: _busy ? null : () => _completeSaved(workout),
                    child: Text(_mutatingId == workout.id
                        ? 'Saving completion…'
                        : 'Mark complete')),
              TextButton(
                  onPressed: _busy ? null : () => _delete(workout),
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error),
                  child: const Text('Delete')),
            ]),
          ],
        ));
  }
}
