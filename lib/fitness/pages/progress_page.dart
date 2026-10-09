import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/progress_model.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage>
    with SingleTickerProviderStateMixin {
  final ProgressRepository _progressRepo = ProgressRepository();
  final WorkoutRepository _workoutRepo = WorkoutRepository();
  final MealRepository _mealRepo = MealRepository();

  late TabController _tabController;
  final TextEditingController _weightController = TextEditingController();

  List<WeightEntry> _weightEntries = [];
  Map<String, dynamic>? _stats;
  int _workoutCount = 0;
  int _streak = 0;
  bool _loading = true;
  String _selectedPeriod = '30';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;

    final weights = await _progressRepo.getWeightEntries(user.uid);
    final stats = await _progressRepo.getProgressStats(user.uid);
    final count = await _workoutRepo.getWorkoutCount(user.uid);
    final streak = await _workoutRepo.getCurrentStreak(user.uid);

    if (!mounted) return;
    setState(() {
      _weightEntries = weights;
      _stats = stats;
      _workoutCount = count;
      _streak = streak;
      _loading = false;
    });
  }

  Future<void> _logWeight() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;

    final text = _weightController.text.trim();
    final weight = double.tryParse(text);

    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid weight'),
            backgroundColor: Pallete.dangerColor),
      );
      return;
    }

    await _progressRepo.addWeightEntry(WeightEntry(
        id: '',
        userId: user.uid,
        weight: weight,
        date: DateTime.now(),
        createdAt: DateTime.now()));
    _weightController.clear();
    Navigator.pop(context);
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Weight logged!'),
            backgroundColor: Pallete.successColor),
      );
    }
  }

  void _showLogDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pallete.cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Pallete.borderColor)),
        title: const Text('Log Weight',
            style: TextStyle(color: Pallete.mainFontColor)),
        content: TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Pallete.mainFontColor),
          decoration: InputDecoration(
            hintText: 'Enter weight in kg',
            hintStyle: const TextStyle(color: Pallete.hintColor),
            filled: true,
            fillColor: Pallete.surfaceColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            suffixText: 'kg',
            suffixStyle: const TextStyle(color: Pallete.subFontColor),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Pallete.subFontColor))),
          TextButton(
              onPressed: _logWeight,
              child: const Text('Save',
                  style: TextStyle(color: Pallete.primaryAccent))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      appBar: AppBar(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('Progress'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add_rounded, color: Pallete.primaryAccent),
              onPressed: _showLogDialog),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Pallete.primaryAccent,
          labelColor: Pallete.primaryAccent,
          unselectedLabelColor: Pallete.subFontColor,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Weight'),
            Tab(text: 'Stats')
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Pallete.primaryAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildWeightTab(),
                _buildStatsTab()
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statCards(),
          const SizedBox(height: 24),
          _weightChart(),
          const SizedBox(height: 24),
          _workoutStats(),
        ],
      ),
    );
  }

  Widget _statCards() {
    final currentWeight = (_stats?['currentWeight'] as num?)?.toDouble();
    final change = (_stats?['weightChange'] as num?)?.toDouble();

    return Row(
      children: [
        _statCard(
          currentWeight != null
              ? '${currentWeight.toStringAsFixed(1)}kg'
              : '--',
          'Current',
          Icons.monitor_weight_outlined,
        ),
        const SizedBox(width: 10),
        _statCard(
          change != null
              ? '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}kg'
              : '--',
          'Change',
          Icons.trending_up_rounded,
        ),
        const SizedBox(width: 10),
        _statCard('$_streak', 'Streak', Icons.local_fire_department_rounded),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
            color: Pallete.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Pallete.borderColor)),
        child: Column(
          children: [
            Icon(icon, color: Pallete.primaryAccent, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Pallete.mainFontColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style:
                    const TextStyle(color: Pallete.subFontColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _weightChart() {
    if (_weightEntries.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Pallete.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Pallete.borderColor)),
        child: const Center(
            child: Text('Log some weights to see the chart',
                style: TextStyle(color: Pallete.subFontColor))),
      );
    }

    final sortedEntries = _weightEntries
      ..sort((a, b) => a.date.compareTo(b.date));
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedEntries[i].weight));
    }

    final minWeight =
        sortedEntries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    final maxWeight =
        sortedEntries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pallete.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weight Progress',
              style: TextStyle(
                  color: Pallete.mainFontColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: minWeight - 2,
                maxY: maxWeight + 2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Pallete.primaryAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: spots.length < 15),
                    belowBarData: BarAreaData(
                        show: true,
                        color: Pallete.primaryAccent.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workoutStats() {
    final weekly = (_stats?['weeklyWorkouts'] as num?)?.toInt() ?? 0;
    final monthly = (_stats?['monthlyWorkouts'] as num?)?.toInt() ?? 0;
    final total = (_stats?['totalWorkouts'] as num?)?.toInt() ?? 0;
    final weeklyCals = (_stats?['weeklyCalories'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pallete.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Workout Stats',
              style: TextStyle(
                  color: Pallete.mainFontColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat('$total', 'Total', Colors.orange),
              _miniStat('$weekly', 'This Week', Colors.blue),
              _miniStat('$monthly', 'This Month', Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Text('Weekly Calories Burned: ~${weeklyCals * 5}',
              style:
                  const TextStyle(color: Pallete.subFontColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label,
              style:
                  const TextStyle(color: Pallete.subFontColor, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildWeightTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Period:',
                  style: TextStyle(color: Pallete.subFontColor)),
              const SizedBox(width: 8),
              ...['7', '30', '90'].map((p) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text('$p days'),
                        selected: _selectedPeriod == p,
                        onSelected: (s) => setState(() => _selectedPeriod = p)),
                  )),
            ],
          ),
        ),
        Expanded(
          child: _weightEntries.isEmpty
              ? const Center(
                  child: Text('No weight entries yet',
                      style: TextStyle(color: Pallete.subFontColor)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _weightEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _weightEntries[index];
                    final dateFormat = DateFormat('MMM dd, yyyy');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Pallete.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Pallete.borderColor)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dateFormat.format(entry.date),
                                    style: const TextStyle(
                                        color: Pallete.subFontColor,
                                        fontSize: 12)),
                                Text('${entry.weight.toStringAsFixed(1)} kg',
                                    style: const TextStyle(
                                        color: Pallete.mainFontColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                          IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Pallete.dangerColor),
                              onPressed: () async {
                                await _progressRepo.deleteWeightEntry(entry.id);
                                _loadData();
                              }),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    final weeklyCals = (_stats?['weeklyCalories'] as num?)?.toDouble() ?? 0.0;
    final monthlyCals = (_stats?['monthlyCalories'] as num?)?.toDouble() ?? 0.0;
    final totalMeals = (_stats?['totalMeals'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nutrition Stats',
              style: TextStyle(
                  color: Pallete.mainFontColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 16),
          _nutritionCard('Weekly', weeklyCals, Colors.orange),
          const SizedBox(height: 12),
          _nutritionCard('Monthly', monthlyCals, Colors.blue),
          const SizedBox(height: 12),
          _nutritionCard('Total Meals Logged', totalMeals, Colors.green),
          const SizedBox(height: 24),
          const Text('Achievements',
              style: TextStyle(
                  color: Pallete.mainFontColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 16),
          _achievementsGrid(),
        ],
      ),
    );
  }

  Widget _nutritionCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.local_fire_department, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Pallete.subFontColor, fontSize: 12)),
                Text('${value.toInt()} kcal',
                    style: const TextStyle(
                        color: Pallete.mainFontColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _achievementsGrid() {
    final achievements = [
      {
        'icon': '🏆',
        'title': 'First Workout',
        'unlocked': _workoutCount >= 1 ? 1 : 0
      },
      {'icon': '🔥', 'title': '7 Day Streak', 'unlocked': _streak >= 7 ? 1 : 0},
      {
        'icon': '💪',
        'title': '10 Workouts',
        'unlocked': _workoutCount >= 10 ? 1 : 0
      },
      {
        'icon': '🏃',
        'title': '30 Day Streak',
        'unlocked': _streak >= 30 ? 1 : 0
      },
      {
        'icon': '🥗',
        'title': 'First Meal Log',
        'unlocked': ((_stats?['totalMeals'] as num?)?.toInt() ?? 0) >= 1 ? 1 : 0
      },
      {
        'icon': '📊',
        'title': 'Log 10 Weights',
        'unlocked': _weightEntries.length >= 10 ? 1 : 0
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: achievements.map((a) {
        final num unlockedNum = a['unlocked'] as num? ?? 0;
        final bool unlocked = unlockedNum.toInt() == 1;
        return Container(
          width: (MediaQuery.of(context).size.width - 64) / 2,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: unlocked
                ? Pallete.successColor.withValues(alpha: 0.1)
                : Pallete.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: unlocked ? Pallete.successColor : Pallete.borderColor),
          ),
          child: Column(
            children: [
              Text(a['icon'] as String, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(a['title'] as String,
                  style: TextStyle(
                      color: unlocked
                          ? Pallete.successColor
                          : Pallete.subFontColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      }).toList(),
    );
  }
}
