import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/workout_model.dart';
import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/pallete.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage>
    with SingleTickerProviderStateMixin {
  final AiService _aiService = AiService();
  final WorkoutRepository _workoutRepo = WorkoutRepository();

  late TabController _tabController;
  String _selectedMuscle = 'Chest';
  String _selectedDifficulty = 'Intermediate';
  String _selectedDuration = '45 min';
  List<Exercise> _exercises = [];
  bool _loading = false;
  bool _generated = false;

  final List<String> _muscles = [
    'Chest',
    'Back',
    'Legs',
    'Arms',
    'Shoulders',
    'Core',
    'Full Body'
  ];
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> _durations = ['20 min', '30 min', '45 min', '60 min'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateWorkout() async {
    setState(() {
      _loading = true;
      _exercises = [];
      _generated = false;
    });

    final result = await _aiService.generateWorkout(
      muscleGroup: _selectedMuscle,
      difficulty: _selectedDifficulty,
      duration: _selectedDuration,
    );

    final lines = result.split('\n').where((l) => l.trim().isNotEmpty);
    final exercises = <Exercise>[];

    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length >= 3) {
        final setsReps = parts[1].trim().split('x');
        exercises.add(Exercise(
          name: parts[0].trim(),
          sets: int.tryParse(setsReps[0].trim()) ?? 3,
          reps: int.tryParse(setsReps[1].trim()) ?? 10,
          muscle: parts[2].trim(),
        ));
      }
    }

    setState(() {
      _exercises = exercises;
      _loading = false;
      _generated = true;
    });
  }

  Future<void> _saveWorkout() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null || _exercises.isEmpty) return;

    final duration =
        int.tryParse(_selectedDuration.replaceAll(' min', '')) ?? 45;

    final workout = Workout(
      id: '',
      userId: user.uid,
      name: '$_selectedMuscle Workout',
      muscleGroup: _selectedMuscle,
      difficulty: _selectedDifficulty,
      durationMinutes: duration,
      exercises: _exercises,
      date: DateTime.now(),
      completed: false,
      createdAt: DateTime.now(),
    );

    await _workoutRepo.createWorkout(workout);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout saved! 💪'),
          backgroundColor: Pallete.successColor,
        ),
      );
      setState(() => _generated = false);
    }
  }

  Future<void> _markAsDone() async {
    await _saveWorkout();
    await _workoutRepo.markWorkoutComplete(_exercises.first.name, true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout completed! Great job 💪'),
          backgroundColor: Pallete.successColor,
        ),
      );
      setState(() => _generated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().currentUser;

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      appBar: AppBar(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('Workouts'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Pallete.primaryAccent,
          labelColor: Pallete.primaryAccent,
          unselectedLabelColor: Pallete.subFontColor,
          tabs: const [
            Tab(text: 'Generate'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneratorTab(),
          _buildHistoryTab(user?.uid ?? ''),
        ],
      ),
    );
  }

  Widget _buildGeneratorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Muscle Group'),
          const SizedBox(height: 10),
          _chipRow(_muscles, _selectedMuscle,
              (v) => setState(() => _selectedMuscle = v)),
          const SizedBox(height: 20),
          _sectionLabel('Difficulty'),
          const SizedBox(height: 10),
          _chipRow(_difficulties, _selectedDifficulty,
              (v) => setState(() => _selectedDifficulty = v)),
          const SizedBox(height: 20),
          _sectionLabel('Duration'),
          const SizedBox(height: 10),
          _chipRow(_durations, _selectedDuration,
              (v) => setState(() => _selectedDuration = v)),
          const SizedBox(height: 24),
          _generateButton(),
          if (_generated && _exercises.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel('Your Workout Plan'),
            const SizedBox(height: 10),
            ..._exercises
                .asMap()
                .entries
                .map((e) => _exerciseCard(e.key, e.value)),
            const SizedBox(height: 16),
            _actionButtons(),
          ],
          if (_generated && _exercises.isEmpty) ...[
            const SizedBox(height: 20),
            const Center(
                child: Text('Could not parse workout. Try again.',
                    style: TextStyle(color: Pallete.subFontColor))),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab(String userId) {
    if (userId.isEmpty) {
      return const Center(
          child: Text('Please login to view history',
              style: TextStyle(color: Pallete.subFontColor)));
    }

    return FutureBuilder<List<Workout>>(
      future: _workoutRepo.getUserWorkouts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final workouts = snapshot.data ?? [];

        if (workouts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center_rounded,
                    size: 64,
                    color: Pallete.subFontColor.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text('No workouts yet',
                    style: TextStyle(color: Pallete.subFontColor)),
                const SizedBox(height: 8),
                const Text('Generate your first workout!',
                    style:
                        TextStyle(color: Pallete.subFontColor, fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final workout = workouts[index];
            return _workoutHistoryCard(workout);
          },
        );
      },
    );
  }

  Widget _workoutHistoryCard(Workout workout) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                workout.completed ? Pallete.successColor : Pallete.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workout.name,
                        style: const TextStyle(
                            color: Pallete.mainFontColor,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        '${workout.muscleGroup} • ${workout.difficulty} • ${workout.durationMinutes}min',
                        style: const TextStyle(
                            color: Pallete.subFontColor, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: workout.completed
                      ? Pallete.successColor.withValues(alpha: 0.2)
                      : Pallete.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  workout.completed ? 'Completed' : 'Pending',
                  style: TextStyle(
                      color: workout.completed
                          ? Pallete.successColor
                          : Pallete.subFontColor,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(dateFormat.format(workout.date),
              style:
                  const TextStyle(color: Pallete.subFontColor, fontSize: 11)),
          if (workout.exercises.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: workout.exercises
                  .take(3)
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Pallete.surfaceColor,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(e.name,
                            style: const TextStyle(
                                color: Pallete.subFontColor, fontSize: 10)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!workout.completed)
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        _workoutRepo.markWorkoutComplete(workout.id, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          color: Pallete.successColor,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Center(
                          child: Text('Mark Complete',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12))),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _workoutRepo.deleteWorkout(workout.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                      color: Pallete.dangerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline,
                      color: Pallete.dangerColor, size: 18),
                ),
              ),
            ],
          ),
        ],
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
                        : Pallete.borderColor),
              ),
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
      onTap: _loading ? null : _generateWorkout,
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
              : const Text('✨ Generate Workout',
                  style: TextStyle(
                      color: Pallete.backgroundColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
        ),
      ),
    );
  }

  Widget _exerciseCard(int index, Exercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor)),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: Pallete.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Pallete.primaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name,
                    style: const TextStyle(
                        color: Pallete.mainFontColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('${exercise.sets} sets x ${exercise.reps} reps',
                    style: const TextStyle(
                        color: Pallete.subFontColor, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Pallete.surfaceColor,
                borderRadius: BorderRadius.circular(8)),
            child: Text(exercise.muscle,
                style:
                    const TextStyle(color: Pallete.subFontColor, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _saveWorkout,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: Pallete.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Pallete.borderColor)),
              child: const Center(
                  child: Text('Save Workout',
                      style: TextStyle(
                          color: Pallete.mainFontColor,
                          fontWeight: FontWeight.bold))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _markAsDone,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: Pallete.successColor,
                  borderRadius: BorderRadius.circular(14)),
              child: const Center(
                  child: Text('Complete',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
            ),
          ),
        ),
      ],
    );
  }
}
