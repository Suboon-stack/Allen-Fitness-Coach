import 'user_profile_model.dart';
import 'progress_tracking_data.dart';

class ProfileStorageException implements Exception {
  const ProfileStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Derived only from the account-owned completion projection, not global keys.
int ownedWorkoutStreak(List<CompletedWorkout> workouts, DateTime now) {
  final days = workouts.where((w) => !w.date.isAfter(now)).map((w) {
    final d = w.date.toLocal();
    return DateTime(d.year, d.month, d.day);
  }).toSet();
  var day = DateTime(now.year, now.month, now.day);
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var count = 0;
  while (days.contains(day)) {
    count++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return count;
}

void validateProfile(UserProfile p) {
  bool invalid(double? value) =>
      value != null && (!value.isFinite || value <= 0);
  if (p.id.isEmpty ||
      (p.name?.length ?? 0) > 200 ||
      p.age != null && (p.age! <= 0 || p.age! > 130) ||
      invalid(p.height) ||
      invalid(p.weight) ||
      p.height != null && p.height! > 300 ||
      p.weight != null && p.weight! > 1000 ||
      p.targetCalories != null && p.targetCalories! <= 0 ||
      [p.targetProtein, p.targetCarbs, p.targetFat].any(invalid) ||
      p.gender != null && !['Male', 'Female', 'Other'].contains(p.gender) ||
      p.goal != null &&
          !['Lose Weight', 'Maintain Weight', 'Gain Muscle'].contains(p.goal)) {
    throw const ProfileStorageException(
        'Check your profile values. Leave optional fields blank or enter valid positive values.');
  }
}
