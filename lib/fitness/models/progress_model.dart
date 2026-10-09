import 'package:cloud_firestore/cloud_firestore.dart';

class WeightEntry {
  final String id;
  final String userId;
  final double weight;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  WeightEntry({
    required this.id,
    required this.userId,
    required this.weight,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  factory WeightEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeightEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      weight: (data['weight'] as num?)?.toDouble() ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'weight': weight,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class WaterIntake {
  final String id;
  final String userId;
  final int amount;
  final DateTime timestamp;
  final DateTime createdAt;

  WaterIntake({
    required this.id,
    required this.userId,
    required this.amount,
    required this.timestamp,
    required this.createdAt,
  });

  factory WaterIntake.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WaterIntake(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: data['amount'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Achievement {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String icon;
  final DateTime unlockedAt;

  Achievement({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlockedAt,
  });

  factory Achievement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Achievement(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '🏆',
      unlockedAt:
          (data['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'icon': icon,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
    };
  }
}

class WorkoutStats {
  final int totalWorkouts;
  final int totalMinutes;
  final int currentStreak;
  final int longestStreak;
  final Map<String, int> muscleGroupCount;

  WorkoutStats({
    required this.totalWorkouts,
    required this.totalMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.muscleGroupCount,
  });
}

class NutritionStats {
  final int totalCaloriesConsumed;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final int totalWaterMl;

  NutritionStats({
    required this.totalCaloriesConsumed,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalWaterMl,
  });
}
