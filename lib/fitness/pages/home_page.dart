import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/pages/chat_page.dart';
import 'package:allen/fitness/pages/meal_planner_page.dart';
import 'package:allen/fitness/pages/profile_page.dart';
import 'package:allen/fitness/pages/progress_page.dart';
import 'package:allen/fitness/pages/settings_page.dart';
import 'package:allen/fitness/pages/workout_page.dart';
import 'package:allen/fitness/pages/about_page.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/allen_components.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:allen/fitness/pages/calorie_scanner_page.dart';

class HomePage extends StatefulWidget {
  const HomePage(
      {super.key,
      this.aiService,
      this.workoutRepository,
      this.progressRepository});
  final AiService? aiService;
  final WorkoutRepository? workoutRepository;
  final ProgressRepository? progressRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AiService _aiService = widget.aiService ?? AiService();
  late final WorkoutRepository _workouts =
      widget.workoutRepository ?? WorkoutRepository();
  late final ProgressRepository _progress =
      widget.progressRepository ?? ProgressRepository();
  String _quote = '';
  bool _quoteFailed = false;
  int _workoutCount = 0;
  int _streak = 0;
  int _water = 0;
  double? _currentWeight;
  bool _loading = true;
  bool _failed = false;
  bool _quoteLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadQuote();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthCubit>().currentUser;
    setState(() {
      _loading = true;
      _failed = false;
    });
    if (user == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    try {
      final (count, weight, streak, water) = await (
        _workouts.getWorkoutCount(user.uid),
        _progress.getLatestWeight(user.uid),
        _workouts.getCurrentStreak(user.uid),
        _progress.getTodayWaterIntake(user.uid),
      ).wait;
      if (!mounted) return;
      setState(() {
        _workoutCount = count;
        _currentWeight = weight?.weight;
        _streak = streak;
        _water = water;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadQuote() async {
    if (_quoteLoading) return;
    setState(() {
      _quoteLoading = true;
      _quoteFailed = false;
    });
    try {
      final quote = await _aiService.getDailyQuote();
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _quoteLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quoteFailed = true;
        _quoteLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    // Quote availability must never hold up local activity or pull-to-refresh.
    _loadQuote();
    await _loadData();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _loadData();
  }

  @override
  Widget build(BuildContext context) => AppThemeScope(
        child: Builder(builder: _buildDashboard),
      );

  Widget _buildDashboard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allen',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5)),
        actions: [
          IconButton(
              tooltip: 'Your profile',
              onPressed: () => _open(const ProfilePage()),
              icon: const Icon(Icons.person_outline_rounded))
        ],
      ),
      drawer: _drawer(context),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: 0,
        backgroundColor: colors.surface,
        indicatorColor: colors.secondaryContainer,
        labelBehavior: MediaQuery.textScalerOf(context).scale(12) > 18
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              _open(const WorkoutPage());
            case 2:
              _open(const MealPlannerPage());
            case 3:
              _open(const ProgressPage());
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_rounded), label: 'Workouts'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_outlined), label: 'Nutrition'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined), label: 'Progress'),
        ],
      ),
      body: SafeArea(
          top: false,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Center(
                  child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppLayout.contentWidth),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(greeting, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text('Your day.', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Material(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  Text('Ask Allen',
                                      style: theme.textTheme.titleMedium),
                                  FilledButton(
                                      onPressed: () => _open(const ChatPage()),
                                      child: const Text('Open coach')),
                                ])),
                      ),
                      const SizedBox(height: 20),
                      Text('Activity', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_loading)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Row(children: [
                              SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 12),
                              Expanded(child: Text('Loading your activity…')),
                            ]))
                      else if (_failed)
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Your activity couldn’t be loaded.'),
                              TextButton(
                                  onPressed: _loadData,
                                  child: const Text('Try again')),
                            ])
                      else ...[
                        AllenMetricGrid(metrics: [
                          AllenMetric(
                              label: 'Completed workouts',
                              value: '$_workoutCount'),
                          AllenMetric(
                              label: 'Latest weight',
                              value: _currentWeight == null
                                  ? 'Not logged'
                                  : '${_currentWeight!.toStringAsFixed(1)} kg'),
                          AllenMetric(
                              label: 'Workout streak',
                              value:
                                  '$_streak ${_streak == 1 ? 'day' : 'days'}'),
                          AllenMetric(
                              label: 'Water today', value: '$_water ml'),
                        ]),
                        if (_workoutCount == 0 &&
                            _currentWeight == null &&
                            _water == 0 &&
                            _streak == 0) ...[
                          const SizedBox(height: 8),
                          const Text(
                              'Start with a workout, meal, or progress log.'),
                        ],
                      ],
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Scan food'),
                        subtitle: const Text('Estimate nutrition from a photo'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _open(const CalorieScannerPage()),
                      ),
                      const Divider(height: 16),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('Daily motivation',
                            style: theme.textTheme.bodyMedium),
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: [
                          if (_quoteLoading)
                            const Padding(
                                padding: EdgeInsets.all(8),
                                child: LinearProgressIndicator(
                                    semanticsLabel: 'Loading daily motivation'))
                          else if (_quoteFailed)
                            TextButton(
                                onPressed: _loadQuote,
                                child: const Text('Retry daily motivation'))
                          else
                            Align(
                                alignment: Alignment.centerLeft,
                                child: Text(_quote)),
                        ],
                      ),
                    ]),
              )),
            ),
          )),
    );
  }

  Widget _drawer(BuildContext context) {
    final email =
        context.read<AuthCubit>().currentUser?.email ?? 'Your account';
    void navigate(Widget page) {
      Navigator.pop(context);
      _open(page);
    }

    return Drawer(
        child: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your Allen',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(email),
          ])),
      const Divider(),
      ListTile(
          selected: true,
          leading: const Icon(Icons.home_outlined),
          title: const Text('Home'),
          onTap: () => Navigator.pop(context)),
      ListTile(
          leading: const Icon(Icons.fitness_center_rounded),
          title: const Text('Workouts'),
          onTap: () => navigate(const WorkoutPage())),
      ListTile(
          leading: const Icon(Icons.restaurant_outlined),
          title: const Text('Meal planner'),
          onTap: () => navigate(const MealPlannerPage())),
      ListTile(
          leading: const Icon(Icons.document_scanner_outlined),
          title: const Text('Calorie scanner'),
          onTap: () => navigate(const CalorieScannerPage())),
      ListTile(
          leading: const Icon(Icons.insights_outlined),
          title: const Text('Progress'),
          onTap: () => navigate(const ProgressPage())),
      ListTile(
          leading: const Icon(Icons.chat_bubble_outline_rounded),
          title: const Text('AI coach'),
          onTap: () => navigate(const ChatPage())),
      const Divider(),
      ListTile(
          leading: const Icon(Icons.person_outline_rounded),
          title: const Text('Profile'),
          onTap: () => navigate(const ProfilePage())),
      ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          onTap: () => navigate(const SettingsPage())),
      ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('About'),
          onTap: () => navigate(const AboutPage())),
      const Divider(),
      ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Sign out'),
          onTap: () {
            Navigator.pop(context);
            context.read<AuthCubit>().logout();
          }),
    ])));
  }
}
