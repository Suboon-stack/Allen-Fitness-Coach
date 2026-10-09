import 'dart:convert';
import 'dart:io';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/data/user_repository.dart';
import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/services/notification_service.dart';
import 'package:allen/pallete.dart';
import 'package:allen/fitness/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final StorageService _storage = StorageService();
  final NotificationService _notifService = NotificationService();
  final UserRepository _userRepo = UserRepository();
  final WorkoutRepository _workoutRepo = WorkoutRepository();
  final MealRepository _mealRepo = MealRepository();
  final ProgressRepository _progressRepo = ProgressRepository();

  bool _workoutReminderEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadReminderStatus();
  }

  Future<void> _loadReminderStatus() async {
    final enabled = await _notifService.isWorkoutReminderEnabled();
    setState(() => _workoutReminderEnabled = enabled);
  }

  Future<void> _toggleWorkoutReminder(bool value) async {
    await _notifService.toggleWorkoutReminder(value);
    setState(() => _workoutReminderEnabled = value);
  }

  Future<void> _exportData() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return;

    try {
      final data = await _userRepo.exportUserData(user.uid);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/allen_data_export.json');
      await file.writeAsString(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported to ${file.path}'),
            backgroundColor: Pallete.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Pallete.dangerColor,
          ),
        );
      }
    }
  }

  void _confirmClear(BuildContext context, String title, String message,
      VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pallete.cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Pallete.borderColor)),
        title:
            Text(title, style: const TextStyle(color: Pallete.mainFontColor)),
        content:
            Text(message, style: const TextStyle(color: Pallete.subFontColor)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Pallete.subFontColor))),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm();
              },
              child: const Text('Confirm',
                  style: TextStyle(color: Pallete.dangerColor))),
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
        title: const Text('Settings'),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(color: Pallete.borderColor, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Notifications'),
            const SizedBox(height: 10),
            _toggleTile(
              icon: Icons.fitness_center_rounded,
              iconColor: Colors.orange,
              title: 'Workout Reminder',
              subtitle: 'Daily workout reminder',
              value: _workoutReminderEnabled,
              onChanged: _toggleWorkoutReminder,
            ),
            const SizedBox(height: 24),
            _sectionLabel('Data'),
            const SizedBox(height: 10),
            _actionTile(
              icon: Icons.download_rounded,
              iconColor: Colors.blue,
              title: 'Export Data',
              subtitle: 'Download all your data as JSON',
              onTap: _exportData,
            ),
            const SizedBox(height: 10),
            _actionTile(
              icon: Icons.delete_sweep_outlined,
              iconColor: Colors.orangeAccent,
              title: 'Clear Weight Logs',
              subtitle: 'Delete all your weight history',
              onTap: () => _confirmClear(context, 'Clear Weight Logs',
                  'This will delete all your weight logs permanently.',
                  () async {
                await _storage.clearWeightLogs();
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Weight logs cleared'),
                      backgroundColor: Pallete.successColor));
              }),
            ),
            const SizedBox(height: 24),
            _sectionLabel('Account'),
            const SizedBox(height: 10),
            _actionTile(
              icon: Icons.logout_rounded,
              iconColor: Colors.orangeAccent,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              onTap: () => context.read<AuthCubit>().logout(),
            ),
            const SizedBox(height: 8),
            _actionTile(
              icon: Icons.delete_outline_rounded,
              iconColor: Pallete.dangerColor,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              onTap: () => _confirmClear(
                  context,
                  'Delete Account',
                  'This will permanently delete your account. This cannot be undone.',
                  () => context.read<AuthCubit>().deleteAccount()),
            ),
            const SizedBox(height: 40),
            const Center(
                child: Text('Allen Fitness v1.0.0',
                    style: TextStyle(color: Pallete.hintColor, fontSize: 12))),
          ],
        ),
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

  Widget _toggleTile(
      {required IconData icon,
      required Color iconColor,
      required String title,
      required String subtitle,
      required bool value,
      required Function(bool) onChanged}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Pallete.mainFontColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Pallete.subFontColor, fontSize: 12)),
              ],
            ),
          ),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Pallete.primaryAccent),
        ],
      ),
    );
  }

  Widget _actionTile(
      {required IconData icon,
      required Color iconColor,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Pallete.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Pallete.borderColor)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Pallete.mainFontColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Pallete.subFontColor, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Pallete.subFontColor),
          ],
        ),
      ),
    );
  }
}
