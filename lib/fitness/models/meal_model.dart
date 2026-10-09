import 'package:cloud_firestore/cloud_firestore.dart';

class Meal {
  final String id;
  final String userId;
  final String name;
  final String mealTime;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  Meal({
    required this.id,
    required this.userId,
    required this.name,
    required this.mealTime,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  factory Meal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meal(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      mealTime: data['mealTime'] ?? '',
      calories: data['calories'] ?? 0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0,
      carbs: (data['carbs'] as num?)?.toDouble() ?? 0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'mealTime': mealTime,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class DailyMealPlan {
  final String id;
  final String userId;
  final String goal;
  final String diet;
  final List<MealPlanItem> meals;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final DateTime date;
  final DateTime createdAt;

  DailyMealPlan({
    required this.id,
    required this.userId,
    required this.goal,
    required this.diet,
    required this.meals,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.date,
    required this.createdAt,
  });
}

class MealPlanItem {
  final String mealTime;
  final String name;
  final int calories;
  final double protein;

  MealPlanItem({
    required this.mealTime,
    required this.name,
    required this.calories,
    required this.protein,
  });

  factory MealPlanItem.fromMap(Map<String, dynamic> map) {
    return MealPlanItem(
      mealTime: map['mealTime'] ?? '',
      name: map['name'] ?? '',
      calories: map['calories'] ?? 0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mealTime': mealTime,
      'name': name,
      'calories': calories,
      'protein': protein,
    };
  }
}
