import 'dart:async';
import 'dart:convert';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/workout_plan_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<String> generate(AiService service) => service.generateWorkout(
      muscleGroup: 'Chest', difficulty: 'Beginner', duration: '20 min');
  test(
      'Workout request uses selected preferences and returns actual Gemini text',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final prompt =
          (body['contents'] as List).last['parts'][0]['text'] as String;
      expect(prompt, contains('Beginner 20 min'));
      expect(prompt, contains('Chest'));
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Push Ups | 3 x 12 | Chest'},
                    {'text': 'Bench Press | 4 x 8 | Chest'}
                  ]
                }
              }
            ]
          }),
          200);
    });
    addTearDown(client.close);
    final source = await generate(AiService(client: client));
    expect(source, 'Push Ups | 3 x 12 | Chest\nBench Press | 4 x 8 | Chest');
    expect(calls, 1);
  });
  for (final status in [401, 403, 429, 500]) {
    test(
        'HTTP $status produces a safe actionable failure, never a fallback workout',
        () async {
      final client = MockClient((_) async => http.Response(
          '{"error":{"message":"private provider details"}}', status));
      addTearDown(client.close);
      await expectLater(
          generate(AiService(client: client)),
          throwsA(isA<WorkoutGenerationException>().having((e) => e.message,
              'message', isNot(contains('private provider details')))));
    });
  }
  for (final body in [
    'not-json',
    '{}',
    '{"candidates":[]}',
    '{"candidates":[{"finishReason":"SAFETY"}]}',
    '{"candidates":[{"content":{"parts":[{"text":""}]}}]}'
  ]) {
    test('Empty/blocked/unreadable Gemini response fails explicitly: $body',
        () async {
      final client = MockClient((_) async => http.Response(body, 200));
      addTearDown(client.close);
      await expectLater(generate(AiService(client: client)),
          throwsA(isA<WorkoutGenerationException>()));
    });
  }
  test('Network errors do not expose request URLs or credentials', () async {
    final client = MockClient(
        (_) async => throw http.ClientException('private-request-url'));
    addTearDown(client.close);
    await expectLater(
        generate(AiService(client: client)),
        throwsA(isA<WorkoutGenerationException>().having((e) => e.message,
            'safe message', isNot(contains('private-request-url')))));
  });
  test('Workout request times out rather than staying in loading forever',
      () async {
    final pending = Completer<http.Response>();
    final client = MockClient((_) => pending.future);
    addTearDown(client.close);
    await expectLater(
        generate(AiService(
            client: client, workoutTimeout: const Duration(milliseconds: 1))),
        throwsA(isA<WorkoutGenerationException>()
            .having((e) => e.message, 'timeout', contains('too long'))));
    pending.complete(http.Response('{}', 200));
  });
  test('Quote calls retain their existing fallback behavior', () async {
    final client = MockClient(
        (_) async => http.Response('{"error":{"message":"unavailable"}}', 500));
    addTearDown(client.close);
    final service = AiService(client: client);
    expect(await service.getDailyQuote(), isNotEmpty);
  });
  test('A truncated Gemini response is not treated as a complete workout',
      () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'candidates': [
            {
              'finishReason': 'MAX_TOKENS',
              'content': {
                'parts': [
                  {'text': 'Push Ups | 3 x 12 | Chest'}
                ]
              }
            }
          ]
        }),
        200));
    addTearDown(client.close);
    await expectLater(
        generate(AiService(client: client)),
        throwsA(isA<WorkoutGenerationException>()
            .having((e) => e.message, 'message', contains('couldn’t finish'))));
  });
}
