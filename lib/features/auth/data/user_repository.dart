import 'package:allen/fitness/models/user_profile_model.dart';
import 'package:allen/fitness/services/local_storage_service.dart';

class UserRepository {
  final LocalStorageService _local = LocalStorageService();

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final data = await _local.getUserProfile();
      if (data != null) {
        return UserProfile(
          id: data['id'] ?? userId,
          email: data['email'] ?? '',
          name: data['name'],
          age: data['age'],
          height: (data['height'] as num?)?.toDouble(),
          weight: (data['weight'] as num?)?.toDouble(),
          gender: data['gender'],
          goal: data['goal'],
          targetCalories: data['targetCalories'],
          targetProtein: (data['targetProtein'] as num?)?.toDouble(),
          targetCarbs: (data['targetCarbs'] as num?)?.toDouble(),
          targetFat: (data['targetFat'] as num?)?.toDouble(),
          createdAt:
              DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
          updatedAt:
              DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> createUserProfile(UserProfile profile) async {
    await _local.saveUserProfile({
      'id': profile.id,
      'email': profile.email,
      'name': profile.name,
      'age': profile.age,
      'height': profile.height,
      'weight': profile.weight,
      'gender': profile.gender,
      'goal': profile.goal,
      'targetCalories': profile.targetCalories,
      'targetProtein': profile.targetProtein,
      'targetCarbs': profile.targetCarbs,
      'targetFat': profile.targetFat,
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': profile.updatedAt.toIso8601String(),
    });
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await createUserProfile(profile);
  }

  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final profile = await getUserProfile(userId);
    final workouts = await _local.getWorkouts();
    final meals = await _local.getMeals();
    final weights = await _local.getWeights();

    return {
      'profile': profile?.toFirestore(),
      'workouts': workouts,
      'meals': meals,
      'weights': weights,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }
}
