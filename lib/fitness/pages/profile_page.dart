import 'package:allen/features/auth/data/user_repository.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/user_profile_model.dart';
import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserRepository _userRepo = UserRepository();
  final WorkoutRepository _workoutRepo = WorkoutRepository();
  final ProgressRepository _progressRepo = ProgressRepository();

  UserProfile? _profile;
  int _workoutCount = 0;
  int _streak = 0;
  double? _currentWeight;
  bool _loading = true;
  bool _isEditing = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetCaloriesController = TextEditingController();
  final _targetProteinController = TextEditingController();
  final _targetCarbsController = TextEditingController();
  final _targetFatController = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedGoal = 'Maintain Weight';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final profile = await _userRepo.getUserProfile(user.uid);
    final count = await _workoutRepo.getWorkoutCount(user.uid);
    final streak = await _workoutRepo.getCurrentStreak(user.uid);
    final weight = await _progressRepo.getLatestWeight(user.uid);

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _workoutCount = count;
      _streak = streak;
      _currentWeight = weight?.weight;
      _loading = false;

      if (profile != null) {
        _nameController.text = profile.name ?? '';
        _ageController.text = profile.age?.toString() ?? '';
        _heightController.text = profile.height?.toString() ?? '';
        _weightController.text = profile.weight?.toString() ?? '';
        _targetCaloriesController.text =
            profile.targetCalories?.toString() ?? '2000';
        _targetProteinController.text =
            profile.targetProtein?.toString() ?? '150';
        _targetCarbsController.text = profile.targetCarbs?.toString() ?? '250';
        _targetFatController.text = profile.targetFat?.toString() ?? '65';
        _selectedGender = profile.gender ?? 'Male';
        _selectedGoal = profile.goal ?? 'Maintain Weight';
      }
    });
  }

  Future<void> _saveProfile() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;

    final profile = UserProfile(
      id: _profile?.id ?? user.uid,
      email: user.email ?? '',
      name: _nameController.text.isNotEmpty ? _nameController.text : null,
      age: int.tryParse(_ageController.text),
      height: double.tryParse(_heightController.text),
      weight: double.tryParse(_weightController.text),
      gender: _selectedGender,
      goal: _selectedGoal,
      targetCalories: int.tryParse(_targetCaloriesController.text),
      targetProtein: double.tryParse(_targetProteinController.text),
      targetCarbs: double.tryParse(_targetCarbsController.text),
      targetFat: double.tryParse(_targetFatController.text),
      createdAt: _profile?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_profile == null) {
      await _userRepo.createUserProfile(profile);
    } else {
      await _userRepo.updateUserProfile(profile);
    }

    setState(() {
      _profile = profile;
      _isEditing = false;
      _currentWeight = profile.weight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().currentUser;

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      appBar: AppBar(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Pallete.borderColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(user),
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  if (_isEditing) _buildEditForm() else _buildProfileInfo(),
                  const SizedBox(height: 24),
                  _buildBMICard(),
                  const SizedBox(height: 24),
                  _buildMacroTargets(),
                  const SizedBox(height: 30),
                  _buildLogoutButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(user) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Pallete.primaryAccent, width: 2),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Pallete.cardColor,
              child: Text(
                _profile?.name?.isNotEmpty == true
                    ? _profile!.name![0].toUpperCase()
                    : (user?.email.substring(0, 1).toUpperCase() ?? 'A'),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Pallete.primaryAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _profile?.name ?? user?.email ?? 'User',
            style: const TextStyle(
              color: Pallete.mainFontColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_profile?.goal != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Pallete.successColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Goal: ${_profile!.goal}',
                style:
                    const TextStyle(color: Pallete.successColor, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('$_workoutCount', 'Workouts', Icons.fitness_center_rounded),
        const SizedBox(width: 10),
        _statCard(
          _currentWeight != null
              ? '${_currentWeight!.toStringAsFixed(1)}kg'
              : '--',
          'Weight',
          Icons.monitor_weight_outlined,
        ),
        const SizedBox(width: 10),
        _statCard('$_streak', 'Streak', Icons.local_fire_department_rounded),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: Pallete.primaryAccent, size: 18),
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

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit Profile',
              style: TextStyle(
                  color: Pallete.mainFontColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTextField(_nameController, 'Name'),
          _buildTextField(_ageController, 'Age',
              keyboardType: TextInputType.number),
          _buildTextField(_heightController, 'Height (cm)',
              keyboardType: TextInputType.number),
          _buildTextField(_weightController, 'Weight (kg)',
              keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          const Text('Gender', style: TextStyle(color: Pallete.subFontColor)),
          const SizedBox(height: 8),
          Row(
            children: ['Male', 'Female', 'Other']
                .map((g) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: _selectedGender == g,
                          onSelected: (selected) =>
                              setState(() => _selectedGender = g),
                          selectedColor: Pallete.primaryAccent,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Goal', style: TextStyle(color: Pallete.subFontColor)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedGoal,
            decoration: InputDecoration(
              filled: true,
              fillColor: Pallete.cardColor,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: ['Lose Weight', 'Maintain Weight', 'Gain Muscle']
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _selectedGoal = v!),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Pallete.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Profile',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Pallete.mainFontColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Pallete.subFontColor),
          filled: true,
          fillColor: Pallete.cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Column(
      children: [
        _infoCard(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _profile?.email ?? 'Not available'),
        const SizedBox(height: 10),
        _infoCard(
            icon: Icons.cake_outlined,
            label: 'Age',
            value: _profile?.age?.toString() ?? 'Not set'),
        const SizedBox(height: 10),
        _infoCard(
            icon: Icons.height_outlined,
            label: 'Height',
            value:
                _profile?.height != null ? '${_profile!.height}cm' : 'Not set'),
        const SizedBox(height: 10),
        _infoCard(
            icon: Icons.monitor_weight_outlined,
            label: 'Current Weight',
            value:
                _profile?.weight != null ? '${_profile!.weight}kg' : 'Not set'),
        const SizedBox(height: 10),
        _infoCard(
            icon: Icons.wc_outlined,
            label: 'Gender',
            value: _profile?.gender ?? 'Not set'),
        const SizedBox(height: 10),
        _infoCard(
            icon: Icons.flag_outlined,
            label: 'Goal',
            value: _profile?.goal ?? 'Not set'),
      ],
    );
  }

  Widget _buildBMICard() {
    final bmi = _profile?.bmi;
    final category = _profile?.bmiCategory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pallete.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Pallete.primaryAccent),
              SizedBox(width: 8),
              Text('BMI Calculator',
                  style: TextStyle(
                      color: Pallete.mainFontColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (bmi != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bmi.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Pallete.mainFontColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    Text(category ?? '',
                        style: const TextStyle(
                            color: Pallete.successColor, fontSize: 14)),
                  ],
                ),
                _buildBMIScale(bmi),
              ],
            ),
          ] else ...[
            const Text('Add your height and weight to calculate BMI',
                style: TextStyle(color: Pallete.subFontColor)),
          ],
        ],
      ),
    );
  }

  Widget _buildBMIScale(double bmi) {
    return Container(
      width: 120,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
            colors: [Colors.blue, Colors.green, Colors.orange, Colors.red]),
      ),
      child: Stack(
        children: [
          Positioned(
            left: (bmi.clamp(15, 35) - 15) * 4,
            child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle)),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroTargets() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pallete.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.restaurant_menu_outlined,
                  color: Pallete.primaryAccent),
              SizedBox(width: 8),
              Text('Daily Targets',
                  style: TextStyle(
                      color: Pallete.mainFontColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _macroItem(
                  'Calories',
                  _profile?.targetCalories?.toString() ?? '2000',
                  'kcal',
                  Colors.orange),
              _macroItem(
                  'Protein',
                  _profile?.targetProtein?.toString() ?? '150',
                  'g',
                  Colors.red),
              _macroItem('Carbs', _profile?.targetCarbs?.toString() ?? '250',
                  'g', Colors.blue),
              _macroItem('Fat', _profile?.targetFat?.toString() ?? '65', 'g',
                  Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroItem(String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style:
                  const TextStyle(color: Pallete.subFontColor, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(unit,
              style:
                  const TextStyle(color: Pallete.subFontColor, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _infoCard(
      {required IconData icon, required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pallete.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Pallete.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Pallete.primaryAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Pallete.subFontColor, fontSize: 11)),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Pallete.mainFontColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => context.read<AuthCubit>().logout(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Pallete.dangerColor),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Pallete.dangerColor, size: 20),
            SizedBox(width: 8),
            Text('Logout',
                style: TextStyle(
                    color: Pallete.dangerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetCaloriesController.dispose();
    _targetProteinController.dispose();
    _targetCarbsController.dispose();
    _targetFatController.dispose();
    super.dispose();
  }
}
