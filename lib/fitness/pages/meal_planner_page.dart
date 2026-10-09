import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/pallete.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


class MealPlannerPage extends StatefulWidget {
  const MealPlannerPage({super.key});

  @override
  State<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends State<MealPlannerPage>
    with SingleTickerProviderStateMixin {
  final AiService _aiService = AiService();
  final MealRepository _mealRepo = MealRepository();
  final ProgressRepository _progressRepo = ProgressRepository();

  late TabController _tabController;

  String _selectedGoal = 'Lose Weight';
  String _selectedDiet = 'No preference';
  int _selectedCalories = 2000;
  List<Map<String, String>> _meals = [];
  bool _loading = false;
  bool _generated = false;

  int _todayCalories = 0;
  double _todayProtein = 0;
  double _todayCarbs = 0;
  double _todayFat = 0;
  int _todayWater = 0;

  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _mealNameController = TextEditingController();
  String _selectedMealTime = 'Breakfast';

  final List<String> _goals = ['Lose Weight', 'Gain Muscle', 'Maintain'];
  final List<String> _diets = [
    'No preference',
    'Vegetarian',
    'Vegan',
    'High Protein',
    'Low Carb'
  ];
  final List<String> _mealTimes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTodayNutrition();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _mealNameController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayNutrition() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;

    final nutrition =
        await _mealRepo.getDailyNutrition(user.uid, DateTime.now());
    final water = await _progressRepo.getTodayWaterIntake(user.uid);

    setState(() {
      _todayCalories = nutrition['calories'] as int;
      _todayProtein = nutrition['protein'] as double;
      _todayCarbs = nutrition['carbs'] as double;
      _todayFat = nutrition['fat'] as double;
      _todayWater = water;
    });
  }

  Future<void> _generateMealPlan() async {
    setState(() {
      _loading = true;
      _meals = [];
      _generated = false;
    });

    final result = await _aiService.generateMealPlan(
      goal: _selectedGoal,
      diet: _selectedDiet,
      calories: _selectedCalories,
    );

    final lines = result.split('\n').where((l) => l.trim().isNotEmpty);
    final meals = <Map<String, String>>[];

    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length >= 4) {
        meals.add({
          'time': parts[0].trim(),
          'name': parts[1].trim(),
          'calories': parts[2].trim(),
          'protein': parts[3].trim(),
        });
      }
    }

    setState(() {
      _meals = meals;
      _loading = false;
      _generated = true;
    });
  }

  Future<void> _addMeal() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;

    final meal = Meal(
      id: '',
      userId: user.uid,
      name: _mealNameController.text,
      mealTime: _selectedMealTime,
      calories: int.tryParse(_caloriesController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await _mealRepo.createMeal(meal);
    _mealNameController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();

    await _loadTodayNutrition();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Meal added!'),
            backgroundColor: Pallete.successColor),
      );
    }
  }

  Future<void> _addWater(int amount) async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;

    await _progressRepo.addWaterIntake(user.uid, amount);
    await _loadTodayNutrition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      appBar: AppBar(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('Nutrition'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Pallete.primaryAccent,
          labelColor: Pallete.primaryAccent,
          unselectedLabelColor: Pallete.subFontColor,
          tabs: const [
            Tab(text: 'Tracker'),
            Tab(text: 'Planner'),
            Tab(text: 'Water'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrackerTab(),
          _buildPlannerTab(),
          _buildWaterTab(),
        ],
      ),
    );
  }

  Widget _buildTrackerTab() {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return const Center(child: Text('Please login'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nutritionSummary(),
          const SizedBox(height: 20),
          _addMealForm(),
          const SizedBox(height: 20),
          _sectionLabel('Today\'s Meals'),
          const SizedBox(height: 10),
          FutureBuilder<List<Meal>>(
            future: _mealRepo.getUserMeals(user.uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final today = DateTime.now();
              final meals = snapshot.data!
                  .where((m) =>
                      m.date.year == today.year &&
                      m.date.month == today.month &&
                      m.date.day == today.day)
                  .toList();
              if (meals.isEmpty) {
                return const Center(
                    child: Text('No meals logged today',
                        style: TextStyle(color: Pallete.subFontColor)));
              }
              return Column(
                  children: meals.map((m) => _mealLogCard(m)).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _nutritionSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pallete.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Today\'s Progress',
                  style: TextStyle(
                      color: Pallete.mainFontColor,
                      fontWeight: FontWeight.bold)),
              Text('$_todayCalories / $_selectedCalories kcal',
                  style: const TextStyle(
                      color: Pallete.primaryAccent,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _progressBar('Calories', _todayCalories.toDouble(),
              _selectedCalories.toDouble(), Colors.orange),
          const SizedBox(height: 12),
          _macroBar('Protein', _todayProtein, 150, Colors.red),
          const SizedBox(height: 8),
          _macroBar('Carbs', _todayCarbs, 250, Colors.blue),
          const SizedBox(height: 8),
          _macroBar('Fat', _todayFat, 65, Colors.green),
        ],
      ),
    );
  }

  Widget _progressBar(String label, double value, double max, Color color) {
    final progress = (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style:
                  const TextStyle(color: Pallete.subFontColor, fontSize: 12)),
          Text('${value.toInt()} / ${max.toInt()}',
              style:
                  const TextStyle(color: Pallete.subFontColor, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Pallete.surfaceColor,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8),
        ),
      ],
    );
  }

  Widget _macroBar(String label, double value, double target, Color color) {
    return Row(
      children: [
        SizedBox(
            width: 50,
            child: Text(label,
                style: const TextStyle(
                    color: Pallete.subFontColor, fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (value / target).clamp(0.0, 1.0),
              backgroundColor: Pallete.surfaceColor,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${value.toInt()}g',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _addMealForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pallete.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Log a Meal',
              style: TextStyle(
                  color: Pallete.mainFontColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedMealTime,
            decoration: InputDecoration(
              filled: true,
              fillColor: Pallete.surfaceColor,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _mealTimes
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t,
                        style: const TextStyle(color: Pallete.mainFontColor))))
                .toList(),
            onChanged: (v) => setState(() => _selectedMealTime = v!),
          ),
          const SizedBox(height: 8),
          TextField(
              controller: _mealNameController,
              style: const TextStyle(color: Pallete.mainFontColor),
              decoration: InputDecoration(
                  labelText: 'Meal Name',
                  labelStyle: const TextStyle(color: Pallete.subFontColor),
                  filled: true,
                  fillColor: Pallete.surfaceColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Pallete.mainFontColor),
                      decoration: InputDecoration(
                          labelText: 'Calories',
                          labelStyle:
                              const TextStyle(color: Pallete.subFontColor),
                          filled: true,
                          fillColor: Pallete.surfaceColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _proteinController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Pallete.mainFontColor),
                      decoration: InputDecoration(
                          labelText: 'Protein (g)',
                          labelStyle:
                              const TextStyle(color: Pallete.subFontColor),
                          filled: true,
                          fillColor: Pallete.surfaceColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: _carbsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Pallete.mainFontColor),
                      decoration: InputDecoration(
                          labelText: 'Carbs (g)',
                          labelStyle:
                              const TextStyle(color: Pallete.subFontColor),
                          filled: true,
                          fillColor: Pallete.surfaceColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _fatController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Pallete.mainFontColor),
                      decoration: InputDecoration(
                          labelText: 'Fat (g)',
                          labelStyle:
                              const TextStyle(color: Pallete.subFontColor),
                          filled: true,
                          fillColor: Pallete.surfaceColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addMeal,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Pallete.primaryAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Add Meal',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealLogCard(Meal meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Pallete.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.restaurant,
                color: Pallete.primaryAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.name,
                    style: const TextStyle(
                        color: Pallete.mainFontColor,
                        fontWeight: FontWeight.bold)),
                Text(meal.mealTime,
                    style: const TextStyle(
                        color: Pallete.subFontColor, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${meal.calories} kcal',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold)),
              Text(
                  'P: ${meal.protein.toInt()}g C: ${meal.carbs.toInt()}g F: ${meal.fat.toInt()}g',
                  style: const TextStyle(
                      color: Pallete.subFontColor, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Your Goal'),
          const SizedBox(height: 10),
          _chipRow(
              _goals, _selectedGoal, (v) => setState(() => _selectedGoal = v)),
          const SizedBox(height: 20),
          _sectionLabel('Diet Preference'),
          const SizedBox(height: 10),
          _chipRow(
              _diets, _selectedDiet, (v) => setState(() => _selectedDiet = v)),
          const SizedBox(height: 20),
          _sectionLabel('Daily Calories Target'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Pallete.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Pallete.borderColor)),
            child: Column(
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Calories',
                          style: TextStyle(color: Pallete.mainFontColor)),
                      Text('$_selectedCalories kcal',
                          style: const TextStyle(
                              color: Pallete.primaryAccent,
                              fontWeight: FontWeight.bold)),
                    ]),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Pallete.primaryAccent,
                    inactiveTrackColor: Pallete.borderColor,
                    thumbColor: Pallete.primaryAccent,
                  ),
                  child: Slider(
                      value: _selectedCalories.toDouble(),
                      min: 1200,
                      max: 4000,
                      divisions: 28,
                      onChanged: (v) =>
                          setState(() => _selectedCalories = v.toInt())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _generateButton(),
          if (_generated && _meals.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel('Your Meal Plan'),
            const SizedBox(height: 10),
            ..._meals.map((meal) => _mealCard(meal)),
          ],
        ],
      ),
    );
  }

  Widget _buildWaterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Pallete.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Pallete.borderColor)),
            child: Column(
              children: [
                const Icon(Icons.water_drop, color: Colors.blue, size: 48),
                const SizedBox(height: 12),
                Text('$_todayWater ml',
                    style: const TextStyle(
                        color: Pallete.mainFontColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const Text('Today\'s water intake',
                    style: TextStyle(color: Pallete.subFontColor)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _waterButton(100),
                    const SizedBox(width: 12),
                    _waterButton(250),
                    const SizedBox(width: 12),
                    _waterButton(500),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Pallete.surfaceColor,
                borderRadius: BorderRadius.circular(12)),
            child: const Column(
              children: [
                Text('Daily Water Goal: 2000ml',
                    style: TextStyle(
                        color: Pallete.mainFontColor,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Stay hydrated for better workout performance!',
                    style: TextStyle(color: Pallete.subFontColor, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _waterButton(int amount) {
    return GestureDetector(
      onTap: () => _addWater(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue)),
        child: Text('+${amount}ml',
            style: const TextStyle(
                color: Colors.blue, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label.toUpperCase(),
        style: const TextStyle(
            color: Pallete.subFontColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5));
  }

  Widget _chipRow(
      List<String> items, String selected, Function(String) onSelect) {
    return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final isSelected = item == selected;
          return GestureDetector(
            onTap: () => onSelect(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: isSelected ? Pallete.primaryAccent : Pallete.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? Pallete.primaryAccent
                          : Pallete.borderColor)),
              child: Text(item,
                  style: TextStyle(
                      color: isSelected
                          ? Pallete.backgroundColor
                          : Pallete.subFontColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
            ),
          );
        }).toList());
  }

  Widget _generateButton() {
    return GestureDetector(
      onTap: _loading ? null : _generateMealPlan,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: _loading ? Pallete.cardColor : Pallete.primaryAccent,
            borderRadius: BorderRadius.circular(14)),
        child: Center(
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Pallete.primaryAccent, strokeWidth: 2))
                : const Text('✨ Generate Meal Plan',
                    style: TextStyle(
                        color: Pallete.backgroundColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15))),
      ),
    );
  }

  Widget _mealCard(Map<String, String> meal) {
    final icons = {
      'Breakfast': '🌅',
      'Lunch': '☀️',
      'Dinner': '🌙',
      'Snack': '🍎'
    };
    final emoji = icons.entries
        .firstWhere(
            (e) =>
                meal['time']?.toLowerCase().contains(e.key.toLowerCase()) ??
                false,
            orElse: () => const MapEntry('', '🍽'))
        .value;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor)),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(meal['time'] ?? '',
                    style: const TextStyle(
                        color: Pallete.subFontColor, fontSize: 11)),
                Text(meal['name'] ?? '',
                    style: const TextStyle(
                        color: Pallete.mainFontColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('${meal['calories']} • ${meal['protein']}',
                    style: const TextStyle(
                        color: Pallete.subFontColor, fontSize: 12)),
              ])),
        ],
      ),
    );
  }
}
