import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:allen/secrets.dart';
import 'package:allen/fitness/services/workout_plan_parser.dart';
import 'package:allen/fitness/services/meal_plan_parser.dart';
import 'package:http/http.dart' as http;

class AiService {
  AiService(
      {http.Client? client,
      Duration workoutTimeout = const Duration(seconds: 30),
      Duration mealTimeout = const Duration(seconds: 30)})
      : _client = client,
        _workoutTimeout = workoutTimeout,
        _mealTimeout = mealTimeout;
  final http.Client? _client;
  final Duration _workoutTimeout;
  final Duration _mealTimeout;
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
    final prompt = '''
Create a $difficulty $duration workout plan focused on $muscleGroup.

Return 5-6 exercises, with one exercise per line and no introductory text:
EXERCISE_NAME | SETS x REPS | MUSCLE
You may append a fourth field with rest or instructions when useful.
Use positive integer sets and repetitions only. Do not use ranges or timed holds;
choose a repetition-based exercise instead. Do not invent equipment preferences.

Example:
Bench Press | 4 x 10 | Chest
Push Ups | 3 x 15 | Chest
''';
    return _callGemini(prompt, useHistory: false, strictWorkout: true);
  }

  // ── Generate meal plan ────────────────────────────────────────
  Future<String> generateMealPlan({
    required String goal,
    required String diet,
    required int calories,
  }) async {
    final prompt = """
Create a daily meal plan for someone who wants to $goal.
Diet preference: $diet
Target calories: $calories kcal
Return breakfast, lunch, dinner and snack, one per line, without introductory text.
Use exactly six pipe-separated fields:
MEAL_TIME | MEAL_NAME | CALORIES | PROTEIN | CARBS | FAT
Calories must be a positive integer in kcal. Macros must be nonnegative grams.
Nutrition values are estimates. Do not claim medical or personalized dietary advice.
""";
    return _callGemini(prompt, useHistory: false, strictMeal: true);
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
  Future<String> _callGemini(String prompt,
      {bool useHistory = true,
      bool strictWorkout = false,
      bool strictMeal = false}) async {
    final strict = strictWorkout || strictMeal;
    final kind = strictMeal ? 'meal plan' : 'workout';
    Exception failure(String message) => strictMeal
        ? MealGenerationException(message)
        : WorkoutGenerationException(message);
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
      final request = (_client?.post ?? http.post)(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': contents}),
      );
      final res = strict
          ? await request.timeout(strictMeal ? _mealTimeout : _workoutTimeout)
          : await request;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final text = strict
            ? _planText(data, kind: kind, failure: failure)
            : data['candidates'][0]['content']['parts'][0]['text'] as String;

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
        if (strict) {
          if (res.statusCode == 429) {
            throw failure(
                'Allen’s $kind request limit has been reached. Please try again later.');
          }
          throw failure(
              'Allen’s $kind generation is unavailable right now. Please try again shortly.');
        }
        final error = jsonDecode(res.body);
        return 'Error: ${error['error']['message'] ?? 'Something went wrong'}';
      }
    } catch (e) {
      if (strict) {
        if (e is WorkoutGenerationException || e is MealGenerationException) {
          rethrow;
        }
        if (e is TimeoutException) {
          throw failure('Allen took too long to respond. Please try again.');
        }
        if (e is FormatException) {
          throw failure(
              'Allen returned an unreadable response. Please try again.');
        }
        throw failure(
            'Couldn’t reach Allen. Check your connection and try again.');
      }
      return 'Error: ${e.toString()}';
    }
  }

  String _planText(dynamic data,
      {required String kind, required Exception Function(String) failure}) {
    if (data is Map &&
        data['candidates'] is List &&
        (data['candidates'] as List).isNotEmpty) {
      final candidate = (data['candidates'] as List).first;
      if (candidate is Map &&
          candidate['finishReason'] != null &&
          candidate['finishReason'] != 'STOP') {
        throw failure('Allen couldn’t finish this $kind. Please try again.');
      }
      if (candidate is Map && candidate['content'] is Map) {
        final parts = candidate['content']['parts'];
        if (parts is List) {
          final text = parts
              .whereType<Map>()
              .map((part) => part['text'])
              .whereType<String>()
              .join('\n')
              .trim();
          if (text.isNotEmpty) return text;
        }
      }
    }
    throw failure(
        'Allen could not return a $kind for this request. Try again or change your preferences.');
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
