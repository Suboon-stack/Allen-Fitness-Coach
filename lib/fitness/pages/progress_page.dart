import 'dart:async';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../models/progress_model.dart';
import '../models/progress_tracking_data.dart';
import '../repositories/progress_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_chart.dart';
import '../widgets/progress_journey.dart';
import '../widgets/progress_metrics.dart';
import '../widgets/progress_timeline.dart';
import '../widgets/weight_entry_sheet.dart';
import 'meal_planner_page.dart';
import 'workout_page.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key, this.repository, this.now});
  final ProgressRepository? repository;
  final DateTime Function()? now;
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage>
    with WidgetsBindingObserver {
  late final _repository = widget.repository ?? ProgressRepository();
  ProgressSnapshot? _snapshot;
  ProgressPeriod _period = ProgressPeriod.month;
  bool _loading = true, _editing = false, _closed = false;
  int _request = 0;
  String? _user, _error;
  Timer? _midnight;
  DateTime _now() => widget.now?.call() ?? DateTime.now();
  String? _verifiedUser() {
    final auth = context.read<AuthCubit>();
    if (auth.state is AuthLoading ||
        auth.state is AuthError &&
            (auth.state as AuthError).sessionUnresolved) {
      return null;
    }
    return auth.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _user = _verifiedUser();
    unawaited(_load());
    _scheduleDay();
  }

  @override
  void dispose() {
    _closed = true;
    _request++;
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
      _scheduleDay();
    }
  }

  void _scheduleDay() {
    _midnight?.cancel();
    final now = _now();
    _midnight =
        Timer(DateTime(now.year, now.month, now.day + 1).difference(now), () {
      if (mounted && !_closed) {
        unawaited(_load());
        _scheduleDay();
      }
    });
  }

  void _accountChanged() {
    final user = _verifiedUser();
    if (user == _user) return;
    _user = user;
    _request++;
    _snapshot = null;
    _error = null;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_closed) return;
    final owner = _verifiedUser(), request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (owner == null) {
      setState(() {
        _snapshot = null;
        _loading = false;
        _error = 'Sign in to view your personal progress.';
      });
      return;
    }
    try {
      final data = await _repository.loadTracking(owner);
      if (!mounted ||
          _closed ||
          request != _request ||
          _verifiedUser() != owner) {
        return;
      }
      setState(() {
        _snapshot = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted &&
          !_closed &&
          request == _request &&
          _verifiedUser() == owner) {
        setState(() {
          _snapshot = null;
          _loading = false;
          _error =
              'Progress couldn’t be loaded. Your saved records have not been changed.';
        });
      }
    }
  }

  void _dismissAfterAccountChange(BuildContext routeContext, String owner) {
    if (_verifiedUser() == owner) return;
    final route = ModalRoute.of(routeContext);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(routeContext);
    navigator.popUntil((candidate) => candidate == route || candidate.isFirst);
    if (route.isActive) navigator.pop();
  }

  Future<void> _weight(BuildContext context, {WeightEntry? entry}) async {
    if (_editing || _closed) return;
    final owner = _verifiedUser();
    if (owner == null ||
        entry != null && (entry.userId != owner || entry.id.isEmpty)) {
      return;
    }
    setState(() => _editing = true);
    final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (sheetContext) => BlocListener<AuthCubit, AuthState>(
            listener: (_, __) {
              _dismissAfterAccountChange(sheetContext, owner);
            },
            child: WeightEntrySheet(
                repository: _repository,
                userId: owner,
                currentUser: _verifiedUser,
                entry: entry)));
    if (!mounted || _closed) return;
    setState(() => _editing = false);
    if (saved == true && _verifiedUser() == owner) {
      await _load();
      if (mounted && context.mounted && !_closed && _verifiedUser() == owner) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Weight history updated.')));
      }
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted && !_closed) await _load();
  }

  Future<void> _details(BuildContext context) async {
    final owner = _verifiedUser();
    if (owner == null || _snapshot == null) return;
    final data =
        ProgressViewData(snapshot: _snapshot!, period: _period, now: _now());
    final entries = data.weights.reversed.toList();
    final selected = await showModalBottomSheet<WeightEntry>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => BlocListener<AuthCubit, AuthState>(
            listener: (_, __) {
              _dismissAfterAccountChange(sheetContext, owner);
            },
            child: SafeArea(
                top: false,
                child: FractionallySizedBox(
                    heightFactor: .75,
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('Measurements · ${_period.label}',
                              style: Theme.of(context).textTheme.titleLarge)),
                      Expanded(
                          child: entries.isEmpty
                              ? const Center(
                                  child:
                                      Text('No measurements in this period.'))
                              : ListView.builder(
                                  itemCount: entries.length,
                                  itemBuilder: (context, index) {
                                    final entry = entries[index];
                                    return ListTile(
                                        title: Text(
                                            '${entry.weight.toStringAsFixed(1)} kg'),
                                        subtitle: Text(
                                            DateFormat('d MMM y, HH:mm')
                                                .format(entry.date)),
                                        trailing: entry.id.isNotEmpty
                                            ? const Icon(Icons.edit_outlined)
                                            : null,
                                        onTap: entry.id.isEmpty
                                            ? null
                                            : () => Navigator.pop(
                                                sheetContext, entry));
                                  })),
                    ])))));
    if (mounted &&
        context.mounted &&
        !_closed &&
        _verifiedUser() == owner &&
        selected != null) {
      await _weight(context, entry: selected);
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
      listener: (_, __) => _accountChanged(),
      child: AppThemeScope(child: Builder(builder: (context) {
        final now = _now(), snapshot = _snapshot;
        final data = snapshot == null
            ? null
            : ProgressViewData(snapshot: snapshot, period: _period, now: now);
        return PopScope(
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                _closed = true;
                _request++;
              }
            },
            child: Scaffold(
                appBar: AppBar(title: const Text('Progress'), actions: [
                  IconButton(
                      tooltip: 'Refresh progress',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh)),
                  IconButton(
                      tooltip: 'Progress data information',
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                                  title: const Text('Your recorded progress'),
                                  content: const SingleChildScrollView(
                                      child: Text(
                                          'Only records belonging to your account appear here. Older weight records without ownership are preserved on this device, but are not assigned to you.\n\nWater remains shared device data and is excluded from personal progress. Rings require saved targets; workout and weight targets have not been set. Food calories are intake, not calories burned.')),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Got it'))
                                  ])),
                      icon: const Icon(Icons.info_outline))
                ]),
                bottomNavigationBar: NavigationBar(
                    selectedIndex: 3,
                    labelBehavior: MediaQuery.textScalerOf(context).scale(12) >
                            18
                        ? NavigationDestinationLabelBehavior.onlyShowSelected
                        : NavigationDestinationLabelBehavior.alwaysShow,
                    onDestinationSelected: (index) {
                      switch (index) {
                        case 0:
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        case 1:
                          _open(const WorkoutPage());
                        case 2:
                          _open(const MealPlannerPage());
                      }
                    },
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.home_outlined), label: 'Home'),
                      NavigationDestination(
                          icon: Icon(Icons.fitness_center), label: 'Workouts'),
                      NavigationDestination(
                          icon: Icon(Icons.restaurant_outlined),
                          label: 'Nutrition'),
                      NavigationDestination(
                          icon: Icon(Icons.insights), label: 'Progress')
                    ]),
                body: SafeArea(
                    top: false,
                    bottom: false,
                    child: RefreshIndicator(
                        onRefresh: _load,
                        child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppSpacing.page),
                            child: Center(
                                child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: AppLayout.contentWidth),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (_loading)
                                            const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 32),
                                                child: Column(children: [
                                                  LinearProgressIndicator(
                                                      semanticsLabel:
                                                          'Loading progress'),
                                                  SizedBox(height: 16),
                                                  Text('Loading your journey…')
                                                ]))
                                          else if (_error != null) ...[
                                            Text(_error!,
                                                key: const Key(
                                                    'progress-error')),
                                            TextButton(
                                                onPressed:
                                                    _verifiedUser() == null
                                                        ? null
                                                        : _load,
                                                child: const Text('Retry'))
                                          ] else if (data != null) ...[
                                            ProgressJourney(
                                                summary: data.journeySummary,
                                                period: _period.label),
                                            if (snapshot!
                                                .unavailable.isNotEmpty)
                                              Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 16),
                                                  child: Semantics(
                                                      liveRegion: true,
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                'Some progress data couldn’t load: ${snapshot.unavailable.map((e) => e.name).join(', ')}. Unavailable values are not shown as zero.',
                                                                style: TextStyle(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .error)),
                                                            TextButton(
                                                                onPressed:
                                                                    _load,
                                                                child:
                                                                    const Text(
                                                                        'Retry'))
                                                          ]))),
                                            const SizedBox(height: 16),
                                            ProgressChart(
                                                entries: data.weights,
                                                period: _period,
                                                now: now,
                                                onPeriod: (period) => setState(
                                                    () => _period = period),
                                                unavailable: snapshot
                                                    .unavailable
                                                    .contains(
                                                        ProgressSource.weights),
                                                onLog: _editing
                                                    ? null
                                                    : () => _weight(context),
                                                onEdit: _editing
                                                    ? null
                                                    : (entry) => _weight(
                                                        context,
                                                        entry: entry),
                                                onDetails: () =>
                                                    _details(context)),
                                            const SizedBox(height: 16),
                                            OutlinedButton.icon(
                                                key: const Key(
                                                    'progress-log-weight'),
                                                onPressed: _editing
                                                    ? null
                                                    : () => _weight(context),
                                                icon: const Icon(Icons.add),
                                                label:
                                                    const Text('Log weight')),
                                            const SizedBox(height: 24),
                                            Text('Key Progress',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall),
                                            const SizedBox(height: 8),
                                            Text(
                                                'Workouts: selected period · Nutrition: today',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall),
                                            const SizedBox(height: 16),
                                            ProgressMetrics(data: data),
                                            const SizedBox(height: 24),
                                            Text('Activity Timeline',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall),
                                            const SizedBox(height: 8),
                                            Text(
                                                '${DateFormat('d MMM y').format(_period.start(now))} – ${DateFormat('d MMM y').format(now)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall),
                                            const SizedBox(height: 16),
                                            ProgressTimeline(
                                                events: data.timeline,
                                                now: now,
                                                onEdit: _editing
                                                    ? null
                                                    : (entry) => _weight(
                                                        context,
                                                        entry: entry)),
                                          ],
                                        ]))))))));
      })));
}
