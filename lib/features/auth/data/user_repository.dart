import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:allen/fitness/models/user_profile_model.dart';
import 'package:allen/fitness/models/profile_overview_data.dart';
import 'package:allen/fitness/services/local_storage_service.dart';

class UserRepository {
  UserRepository({String? Function()? authenticatedUser})
      : _currentUser = authenticatedUser ?? _firebaseUser;
  final LocalStorageService _local = LocalStorageService();
  final String? Function() _currentUser;
  static String? _firebaseUser() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static Future<void>? _tail;
  static Future<T> _write<T>(Future<T> Function() work) {
    final previous = _tail;
    final result =
        previous == null ? Future<T>.sync(work) : previous.then((_) => work());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _tail = tail;
    return result.whenComplete(() {
      if (identical(_tail, tail)) _tail = null;
    });
  }

  void _owner(String id) {
    if (id.isEmpty || _currentUser() != id) {
      throw const ProfileStorageException(
          'Your session changed. Close this page and sign in again.');
    }
  }

  Future<Map<String, dynamic>?> _read(String id) async {
    _owner(id);
    final pending = _tail;
    if (pending != null) await pending;
    final data = await _local.getUserProfile(userId: id);
    _owner(id);
    return data;
  }

  UserProfile _decode(Map<String, dynamic> d) {
    double? number(String key) =>
        d[key] == null ? null : (d[key] as num).toDouble();
    final p = UserProfile(
        id: d['id'],
        email: d['email'] ?? '',
        name: d['name'],
        age: d['age'],
        height: number('height'),
        weight: number('weight'),
        gender: d['gender'],
        goal: d['goal'],
        targetCalories: d['targetCalories'],
        targetProtein: number('targetProtein'),
        targetCarbs: number('targetCarbs'),
        targetFat: number('targetFat'),
        createdAt: DateTime.tryParse(d['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(d['updatedAt'] ?? '') ?? DateTime.now());
    validateProfile(p);
    return p;
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final data = await _read(userId);
      return data == null ? null : _decode(data);
    } on ProfileStorageException {
      rethrow;
    } catch (_) {
      throw const ProfileStorageException(
          'Your profile couldn’t be read. Retry; stored data has not been changed.');
    }
  }

  Map<String, dynamic> _encode(UserProfile p) => {
        'id': p.id,
        'email': p.email,
        'name': p.name,
        'age': p.age,
        'height': p.height,
        'weight': p.weight,
        'gender': p.gender,
        'goal': p.goal,
        'targetCalories': p.targetCalories,
        'targetProtein': p.targetProtein,
        'targetCarbs': p.targetCarbs,
        'targetFat': p.targetFat,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String()
      };
  Future<void> createUserProfile(UserProfile profile) async {
    _owner(profile.id);
    validateProfile(profile);
    await _write(() async {
      _owner(profile.id);
      final existing = await _local.getUserProfile(userId: profile.id);
      _owner(profile.id);
      final data = {...?existing, ..._encode(profile)};
      if (existing?['createdAt'] is String) {
        data['createdAt'] = existing!['createdAt'];
      }
      await _local.saveOwnedUserProfile(profile.id, data);
      _owner(profile.id);
    });
  }

  Future<void> updateUserProfile(UserProfile profile) =>
      createUserProfile(profile);
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    _owner(userId);
    final profile = await _read(userId);
    _owner(userId);
    final workouts = await _local.getWorkouts();
    _owner(userId);
    final meals = await _local.getMeals();
    _owner(userId);
    final weights = await _local.getWeights();
    _owner(userId);
    final result = <String, dynamic>{
      'userId': userId,
      'profile': profile,
      'workouts': workouts.where((r) => r['userId'] == userId).toList(),
      'meals': meals.where((r) => r['userId'] == userId).toList(),
      'weights': weights.where((r) => r['userId'] == userId).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'excluded': [
        'Unowned legacy records',
        'Shared device water totals',
        'Temporary AI chats and unconfirmed plans',
        'Notification/device preferences'
      ],
    };
    // Only JSON-native local records are exported; never Firestore Timestamps.
    jsonEncode(result);
    _owner(userId);
    return result;
  }
}
