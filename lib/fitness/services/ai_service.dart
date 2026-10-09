import 'dart:convert';
import 'dart:io';

import 'package:allen/secrets.dart';
import 'package:http/http.dart' as http;

class AiService {
  final List<Map<String, dynamic>> _chatHistory = [];

  // System prompt — makes Gemini act as fitness coach
  final Map<String, dynamic> _systemPrompt = {
    'role': 'user',
    'parts': [
      {
        'text': '''You are Allen, a professional AI fitness coach. 
You ONLY answer questions related to:
- Workouts and exercises
- Nutrition and meal planning
- Weight loss and muscle gain
- Fitness goals and progress
- Health and wellness tips

If someone asks something unrelated to fitness, 
politely redirect them back to fitness topics.
Keep responses friendly, motivating and concise.
Use emojis occasionally to keep it engaging.'''
      }
    ],
  };

  final Map<String, dynamic> _systemResponse = {
    'role': 'model',
    'parts': [
      {
        'text':
            'Understood! I am Allen, your personal AI fitness coach. I am here to help you with workouts, nutrition, and achieving your fitness goals. How can I help you today? 💪'
      }
    ],
  };

  // ── Chat ──────────────────────────────────────────────────────
  Future<String> chat(String prompt) async {
    try {
      final result = await _callGemini(prompt, useHistory: true);

      if (result.contains('quota') ||
          result.contains('rate limit') ||
          result.contains('429')) {
        return 'Sorry, I\'ve reached my daily limit. Please try again later! 💪';
      }

      return result;
    } catch (e) {
      return 'Oops! Something went wrong. Please try again! 😅';
    }
  }

  // ── Generate workout plan ─────────────────────────────────────
  Future<String> generateWorkout({
    required String muscleGroup,
    required String difficulty,
    required String duration,
  }) async {
    try {
      final prompt = '''
Create a $difficulty $duration workout plan focused on $muscleGroup.

Format your response EXACTLY like this with no extra text:
EXERCISE_NAME | SETS x REPS | MUSCLE
EXERCISE_NAME | SETS x REPS | MUSCLE
(list 5-6 exercises)

Example:
Bench Press | 4 x 10 | Chest
Push Ups | 3 x 15 | Chest
''';
      final result = await _callGemini(prompt, useHistory: false);

      if (result.contains('quota') ||
          result.contains('rate limit') ||
          result.contains('429') ||
          result.contains('Error:')) {
        return _getFallbackWorkout(muscleGroup);
      }

      return result;
    } catch (e) {
      return _getFallbackWorkout(muscleGroup);
    }
  }

  String _getFallbackWorkout(String muscleGroup) {
    final workouts = {
      'Chest':
          'Bench Press | 4 x 10 | Chest\nPush Ups | 3 x 15 | Chest\nIncline Press | 3 x 12 | Chest\nCable Fly | 3 x 12 | Chest\nDips | 3 x 10 | Chest',
      'Back':
          'Pull Ups | 3 x 10 | Back\nBarbell Row | 3 x 10 | Back\nLat Pulldown | 3 x 12 | Back\nDeadlift | 3 x 8 | Back\nSeated Row | 3 x 12 | Back',
      'Legs':
          'Squats | 4 x 10 | Legs\nLunges | 3 x 12 | Legs\nLeg Press | 3 x 12 | Legs\nLeg Curl | 3 x 12 | Legs\nCalf Raise | 4 x 15 | Legs',
      'Arms':
          'Barbell Curl | 3 x 10 | Arms\nTricep Dips | 3 x 12 | Arms\nHammer Curl | 3 x 12 | Arms\nSkull Crushers | 3 x 12 | Arms\nPreacher Curl | 3 x 10 | Arms',
      'Shoulders':
          'Overhead Press | 4 x 10 | Shoulders\nLateral Raise | 3 x 12 | Shoulders\nFront Raise | 3 x 12 | Shoulders\nFace Pull | 3 x 12 | Shoulders\nRear Delt Fly | 3 x 12 | Shoulders',
      'Core':
          'Plank | 3 x 60s | Core\nCrunches | 3 x 20 | Core\nLeg Raises | 3 x 15 | Core\nRussian Twist | 3 x 20 | Core\nMountain Climbers | 3 x 30 | Core',
      'Full Body':
          'Burpees | 3 x 10 | Full Body\nPush Ups | 3 x 15 | Full Body\nSquats | 3 x 15 | Full Body\nPull Ups | 3 x 8 | Full Body\nPlank | 3 x 45s | Full Body',
    };
    return workouts[muscleGroup] ?? workouts['Full Body']!;
  }

  // ── Generate meal plan ────────────────────────────────────────
  Future<String> generateMealPlan({
    required String goal,
    required String diet,
    required int calories,
  }) async {
    try {
      final prompt = '''
Create a daily meal plan for someone who wants to $goal.
Diet preference: $diet
Target calories: $calories kcal

Format your response EXACTLY like this:
MEAL_TIME | MEAL_NAME | CALORIES | PROTEIN
MEAL_TIME | MEAL_NAME | CALORIES | PROTEIN
(list breakfast, lunch, dinner, snack)

Example:
Breakfast | Oatmeal + Banana | 380 kcal | 12g protein
Lunch | Grilled Chicken + Rice | 620 kcal | 45g protein
''';
      final result = await _callGemini(prompt, useHistory: false);

      if (result.contains('quota') ||
          result.contains('rate limit') ||
          result.contains('429') ||
          result.contains('Error:')) {
        return _getFallbackMealPlan(goal, calories);
      }

      return result;
    } catch (e) {
      return _getFallbackMealPlan(goal, calories);
    }
  }

  String _getFallbackMealPlan(String goal, int calories) {
    final mealPlan = {
      'Lose Weight':
          'Breakfast | Oatmeal + Berries | 300 kcal | 10g protein\nLunch | Grilled Chicken Salad | 400 kcal | 35g protein\nSnack | Apple + Almonds | 150 kcal | 5g protein\nDinner | Baked Salmon + Vegetables | 450 kcal | 30g protein',
      'Gain Muscle':
          'Breakfast | Eggs + Toast + Banana | 500 kcal | 25g protein\nLunch | Chicken + Rice + Avocado | 650 kcal | 45g protein\nSnack | Protein Shake + Peanut Butter | 300 kcal | 30g protein\nDinner | Steak + Potatoes + Broccoli | 700 kcal | 50g protein',
      'Maintain':
          'Breakfast | Greek Yogurt + Granola | 350 kcal | 20g protein\nLunch | Turkey Wrap + Veggies | 450 kcal | 30g protein\nSnack | Mixed Nuts | 200 kcal | 8g protein\nDinner | Grilled Fish + Quinoa | 500 kcal | 35g protein',
    };
    return mealPlan[goal] ?? mealPlan['Maintain']!;
  }

  // ── Generate daily quote ──────────────────────────────────────
  Future<String> getDailyQuote() async {
    try {
      const prompt =
          'Give me one short motivational fitness quote. Just the quote and author, nothing else. Format: "quote" - Author';
      final result = await _callGemini(prompt, useHistory: false);

      // Check for quota or API errors
      if (result.contains('quota') ||
          result.contains('rate limit') ||
          result.contains('429') ||
          result.contains('Error')) {
        return _getFallbackQuote();
      }

      return result;
    } catch (e) {
      return _getFallbackQuote();
    }
  }

  String _getFallbackQuote() {
    final quotes = [
      '"The only bad workout is the one that didn\'t happen." - Unknown',
      '"Success starts with self-discipline." - Unknown',
      '"Your body can stand almost anything. It\'s your mind you have to convince." - Unknown',
      '"The pain you feel today will be the strength you feel tomorrow." - Unknown',
      '"Don\'t stop when you\'re tired. Stop when you\'re done." - Unknown',
      '"Motivation is what gets you started. Habit is what keeps you going." - Jim Ryun',
      '"The gym is where the magic happens." - Unknown',
      '"Sweat is just fat crying." - Unknown',
      '"Push yourself because no one else is going to do it for you." - Unknown',
      '"Great things never come from comfort zones." - Unknown',
    ];
    return quotes[DateTime.now().millisecond % quotes.length];
  }

  // ── Internal Gemini call ──────────────────────────────────────
  Future<String> _callGemini(String prompt, {bool useHistory = true}) async {
    if (prompt.trim().isEmpty) return 'Please enter a message.';

    const model = 'gemini-2.5-flash-lite';
    final cleanKey = geminiAPIKey.trim();
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$cleanKey',
    );

    final List<Map<String, dynamic>> contents = [
      _systemPrompt,
      _systemResponse,
    ];

    if (useHistory) {
      contents.addAll(_chatHistory);
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt.trim()}
      ],
    });

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': contents}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

        if (useHistory) {
          _chatHistory.add({
            'role': 'user',
            'parts': [
              {'text': prompt.trim()}
            ],
          });
          _chatHistory.add({
            'role': 'model',
            'parts': [
              {'text': text}
            ],
          });
        }

        return text.trim();
      } else {
        final error = jsonDecode(res.body);
        return 'Error: ${error['error']['message'] ?? 'Something went wrong'}';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  void clearHistory() {
    _chatHistory.clear();
  }

  Future<String> analyzeFood(File imageFile) async {
    try {
      const model = 'gemini-2.5-flash-lite';
      final cleanKey = geminiAPIKey.trim();
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$cleanKey',
      );

      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Get file extension for mime type
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final body = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image,
                }
              },
              {
                'text':
                    '''You are a nutrition expert. Analyze this food image and provide:
1. What food items you can see
2. Estimated total calories
3. Estimated macros (protein, carbs, fat)
4. A short health tip about this meal

Format your response EXACTLY like this:
FOOD: [food items you see]
CALORIES: [estimated calories] kcal
PROTEIN: [grams]g
CARBS: [grams]g
FAT: [grams]g
TIP: [short health tip]

Be realistic with estimates. If you cannot identify the food clearly, say so.'''
              }
            ]
          }
        ]
      });

      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        final error = jsonDecode(res.body);
        return 'Error: ${error['error']['message'] ?? 'Could not analyze image'}';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }
}
