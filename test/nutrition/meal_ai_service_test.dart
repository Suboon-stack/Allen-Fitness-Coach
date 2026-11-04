import 'dart:async';
import 'dart:convert';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/meal_plan_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'meal_plan_parser_test.dart' show fullPlan;

void main() {
  Future<String> generate(AiService ai) =>
      ai.generateMealPlan(goal: 'Maintain', diet: 'Vegan', calories: 2100);
  test('Uses preferences, same Gemini endpoint and complete supplied text',
      () async {
    final client = MockClient((request) async {
      expect(
          request.url.path, contains('gemini-2.5-flash-lite:generateContent'));
      final prompt = jsonDecode(request.body)['contents'].last['parts'][0]
          ['text'] as String;
      for (final value in ['Maintain', 'Vegan', '2100', 'CARBS', 'FAT']) {
        expect(prompt, contains(value));
      }
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'finishReason': 'STOP',
                'content': {
                  'parts': [
                    {'text': fullPlan}
                  ]
                }
              }
            ]
          }),
          200);
    });
    addTearDown(client.close);
    expect(await generate(AiService(client: client)), fullPlan);
  });
  for (final status in [401, 403, 429, 500]) {
    test('HTTP $status gives a safe error instead of predefined meals',
        () async {
      final client = MockClient((_) async => http.Response(
          '{"error":{"message":"private upstream details"}}', status));
      addTearDown(client.close);
      await expectLater(
          generate(AiService(client: client)),
          throwsA(isA<MealGenerationException>().having((e) => e.message,
              'safe message', isNot(contains('private upstream')))));
    });
  }
  for (final response in [
    'not json',
    '{}',
    '{"candidates":[]}',
    '{"candidates":[{"finishReason":"SAFETY"}]}',
    '{"candidates":[{"finishReason":"MAX_TOKENS","content":{"parts":[{"text":"Breakfast | Oats | 400 | 20"}]}}]}',
    '{"candidates":[{"content":{"parts":[{"text":""}]}}]}'
  ]) {
    test(
        'Unreadable, blocked or truncated response produces a meal error: $response',
        () async {
      final client = MockClient((_) async => http.Response(response, 200));
      addTearDown(client.close);
      await expectLater(generate(AiService(client: client)),
          throwsA(isA<MealGenerationException>()));
    });
  }
  test('Timeout and transport errors expose no private URLs', () async {
    final pending = Completer<http.Response>();
    final client = MockClient((_) => pending.future);
    addTearDown(client.close);
    await expectLater(
        generate(AiService(
            client: client, mealTimeout: const Duration(milliseconds: 1))),
        throwsA(isA<MealGenerationException>()
            .having((e) => e.message, 'timeout', contains('too long'))));
    pending.complete(http.Response('{}', 200));
    final offline = MockClient(
        (_) async => throw http.ClientException('private request url'));
    addTearDown(offline.close);
    await expectLater(
        generate(AiService(client: offline)),
        throwsA(isA<MealGenerationException>().having((e) => e.message,
            'safe network error', isNot(contains('private')))));
  });
}
