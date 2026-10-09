import 'package:cloud_firestore/cloud_firestore.dart';

class Workout {
  final String id;
  final String userId;
  final String name;
  final String muscleGroup;
  final String difficulty;
  final int durationMinutes;
  final List<Exercise> exercises;
  final DateTime date;
  final bool completed;
  final String? notes;
  final DateTime createdAt;

  Workout({
    required this.id,
    required this.userId,
    required this.name,
    required this.muscleGroup,
    required this.difficulty,
    required this.durationMinutes,
    required this.exercises,
    required this.date,
    this.completed = false,
    this.notes,
    required this.createdAt,
  });

  factory Workout.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Workout(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      muscleGroup: data['muscleGroup'] ?? '',
      difficulty: data['difficulty'] ?? '',
      durationMinutes: data['durationMinutes'] ?? 0,
      exercises: (data['exercises'] as List<dynamic>?)
              ?.map((e) => Exercise.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completed: data['completed'] ?? false,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'muscleGroup': muscleGroup,
      'difficulty': difficulty,
      'durationMinutes': durationMinutes,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'date': Timestamp.fromDate(date),
      'completed': completed,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Exercise {
  final String name;
  final int sets;
  final int reps;
  final double? weight;
  final String muscle;
  final bool completed;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.weight,
    required this.muscle,
    this.completed = false,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      name: map['name'] ?? '',
      sets: map['sets'] ?? 0,
      reps: map['reps'] ?? 0,
      weight: (map['weight'] as num?)?.toDouble(),
      muscle: map['muscle'] ?? '',
      completed: map['completed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'muscle': muscle,
      'completed': completed,
    };
  }

  Exercise copyWith({bool? completed, double? weight}) {
    return Exercise(
      name: name,
      sets: sets,
      reps: reps,
      weight: weight ?? this.weight,
      muscle: muscle,
      completed: completed ?? this.completed,
    );
  }
}
