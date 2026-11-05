import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:allen/fitness/models/food_estimate.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/gemini_food_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const testEstimate = {
  'foodName': 'Rice bowl',
  'calories': 450,
  'protein': 20,
  'carbs': 60,
  'fat': 12
};
http.Response foodReply(dynamic data, {String reason = 'STOP'}) =>
    http.Response(
        jsonEncode({
          'candidates': [
            {
              'finishReason': reason,
              'content': {
                'parts': [
                  {'text': jsonEncode(data)}
                ]
              }
            }
          ]
        }),
        200);
Matcher foodFails(FoodScanFailure value) => throwsA(
    isA<FoodScanException>().having((e) => e.failure, 'safe failure', value));

void main() {
  late Directory temp;
  late File photo;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('allen-food-test-');
    photo =
        await File('${temp.path}/photo.jpg').writeAsBytes([255, 216, 255, 0]);
  });
  tearDown(() async => temp.delete(recursive: true));
  GeminiFoodAnalyzer analyzer(http.Client client,
          {Duration timeout = const Duration(seconds: 30)}) =>
      GeminiFoodAnalyzer(
          apiKey: 'test-food-key', client: client, timeout: timeout);

  test(
      'Existing Gemini model receives image and isolated JSON request; returns real values',
      () async {
    final client = MockClient((request) async {
      expect(
          request.url.path, contains('gemini-2.5-flash-lite:generateContent'));
      final body = jsonDecode(request.body);
      expect(body['contents'].length, 1);
      expect(body['contents'][0]['parts'][0]['inline_data']['mime_type'],
          'image/jpeg');
      expect(
          base64Decode(body['contents'][0]['parts'][0]['inline_data']['data']),
          [255, 216, 255, 0]);
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      return foodReply({
        ...testEstimate,
        'portion': '1 bowl',
        'tip': 'Include a variety of foods.',
        'items': [
          {'name': 'Rice', 'portion': '1 cup'},
          {'name': 'Beans'}
        ]
      });
    });
    addTearDown(client.close);
    final result = await analyzer(client).analyze(photo);
    expect(result.name, 'Rice bowl');
    expect(result.calories, 450);
    expect(result.items[1].portion, isNull);
    expect(result.tip, 'Include a variety of foods.');
    expect(result.items.length, 2);
    expect(result.nutritionNotes, startsWith(FoodEstimate.notePrefix));
  });
  test(
      'AiService uses injected transport and preserves legacy labeled entry point',
      () async {
    final client = MockClient((_) async => foodReply(testEstimate));
    addTearDown(client.close);
    final ai = AiService(client: client);
    expect((await ai.analyzeFoodEstimate(photo)).calories, 450);
    expect(await ai.analyzeFood(photo),
        contains('FOOD: Rice bowl\nCALORIES: 450 kcal'));
  });
  for (final entry in <String, dynamic>{
    'invalid JSON': 'not json',
    'null': null,
    'array': [],
    'empty name': {...testEstimate, 'foodName': ''},
    'missing fat': {
      'foodName': 'Rice',
      'calories': 400,
      'protein': 3,
      'carbs': 4
    },
    'negative': {...testEstimate, 'protein': -1},
    'numeric string': {...testEstimate, 'fat': '12'},
    'fractional calories': {...testEstimate, 'calories': 450.5},
    'invalid items': {
      ...testEstimate,
      'items': ['rice']
    },
    'empty portion': {...testEstimate, 'portion': ''},
    'invented null item': {
      ...testEstimate,
      'items': [
        {'name': null}
      ]
    },
  }.entries) {
    test('Rejects incomplete/malformed estimate: ${entry.key}', () async {
      final client = MockClient((_) async => foodReply(entry.value));
      addTearDown(client.close);
      await expectLater(analyzer(client).analyze(photo),
          foodFails(FoodScanFailure.malformed));
    });
  }
  for (final entry in {
    'SAFETY': FoodScanFailure.blocked,
    'MAX_TOKENS': FoodScanFailure.truncated,
    'OTHER': FoodScanFailure.malformed,
  }.entries) {
    test('Rejects finish reason ${entry.key}', () async {
      final client =
          MockClient((_) async => foodReply(testEstimate, reason: entry.key));
      addTearDown(client.close);
      await expectLater(
          analyzer(client).analyze(photo), foodFails(entry.value));
    });
  }
  for (final data in [
    {},
    {
      'promptFeedback': {'blockReason': 'SAFETY'}
    },
    {
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {
            'parts': [
              {'text': ''}
            ]
          }
        }
      ]
    },
    {
      'candidates': [
        {
          'finishReason': 'STOP',
          'safetyRatings': [
            {'blocked': true}
          ]
        }
      ]
    },
    {
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {
            'parts': [
              {'text': 17}
            ]
          }
        }
      ]
    },
  ]) {
    test(
        'Rejects empty, blocked or malformed provider envelope ${jsonEncode(data)}',
        () async {
      final client =
          MockClient((_) async => http.Response(jsonEncode(data), 200));
      addTearDown(client.close);
      await expectLater(
          analyzer(client).analyze(photo), throwsA(isA<FoodScanException>()));
    });
  }
  for (final status in [400, 401, 403, 408, 429, 500, 503, 504]) {
    test('HTTP $status is safely mapped without secrets/logs', () async {
      final messages = <String>[];
      await runZoned(() async {
        final client = MockClient((_) async => http.Response(
            '{"error":{"message":"test-food-key private https://secret.invalid"}}',
            status));
        addTearDown(client.close);
        await expectLater(
            analyzer(client).analyze(photo),
            throwsA(isA<FoodScanException>().having(
                (e) => e.message,
                'safe text',
                allOf(isNot(contains('test-food-key')),
                    isNot(contains('https://')), isNot(contains('private'))))));
      },
          zoneSpecification: ZoneSpecification(
              print: (_, __, ___, line) => messages.add(line)));
      expect(messages, isEmpty);
    });
  }
  test('Structured HTTP200 provider error is not a successful estimate',
      () async {
    final client = MockClient((_) async => http.Response(
        '{"error":{"code":429,"status":"RESOURCE_EXHAUSTED"}}', 200));
    addTearDown(client.close);
    await expectLater(analyzer(client).analyze(photo),
        foodFails(FoodScanFailure.rateLimited));
  });
  test('Structured invalid-key reason maps to configuration, not a photo error',
      () async {
    final client = MockClient((_) async => http.Response(
        '{"error":{"status":"INVALID_ARGUMENT","details":[{"reason":"API_KEY_INVALID"}]}}',
        400));
    addTearDown(client.close);
    await expectLater(analyzer(client).analyze(photo),
        foodFails(FoodScanFailure.configuration));
  });
  test('Secret-bearing success response is rejected', () async {
    final client = MockClient(
        (_) async => foodReply({...testEstimate, 'foodName': 'test-food-key'}));
    addTearDown(client.close);
    await expectLater(
        analyzer(client).analyze(photo), foodFails(FoodScanFailure.malformed));
  });
  test(
      'MIME comes from bytes; unsupported, unreadable and oversized files never upload',
      () async {
    var requests = 0;
    final client = MockClient((r) async {
      requests++;
      expect(
          jsonDecode(r.body)['contents'][0]['parts'][0]['inline_data']
              ['mime_type'],
          'image/png');
      return foodReply(testEstimate);
    });
    addTearDown(client.close);
    final ai = analyzer(client);
    await photo.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
    await ai.analyze(photo);
    await photo.writeAsString('unsupported HEIC');
    await expectLater(ai.analyze(photo), foodFails(FoodScanFailure.image));
    await photo
        .writeAsBytes(List.filled(GeminiFoodAnalyzer.maxImageBytes + 1, 0));
    await expectLater(ai.analyze(photo), foodFails(FoodScanFailure.image));
    await photo.delete();
    await expectLater(ai.analyze(photo), foodFails(FoodScanFailure.image));
    expect(requests, 1);
  });
  test('Network failure is sanitized and retry succeeds', () async {
    var calls = 0;
    final client = MockClient((_) async {
      if (++calls == 1) {
        throw http.ClientException(
            'private test-food-key', Uri.parse('https://private.invalid'));
      }
      return foodReply(testEstimate);
    });
    addTearDown(client.close);
    final ai = analyzer(client);
    await expectLater(ai.analyze(photo), foodFails(FoodScanFailure.network));
    expect((await ai.analyze(photo)).calories, 450);
  });
  test('Timeout invalidates late responses and permits retry', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((_) =>
        ++calls == 1 ? pending.future : Future.value(foodReply(testEstimate)));
    addTearDown(client.close);
    final ai = analyzer(client, timeout: const Duration(milliseconds: 20));
    await expectLater(ai.analyze(photo), foodFails(FoodScanFailure.timeout));
    expect((await ai.analyze(photo)).name, 'Rice bowl');
    pending.complete(foodReply({...testEstimate, 'foodName': 'Stale'}));
    await Future<void>.delayed(Duration.zero);
  });
  test('Overlapping analysis blocked and cancelled replies rejected', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final client = MockClient((_) {
      started.complete();
      return pending.future;
    });
    addTearDown(client.close);
    final ai = analyzer(client);
    final first = ai.analyze(photo);
    await started.future;
    await expectLater(ai.analyze(photo), foodFails(FoodScanFailure.busy));
    ai.cancel();
    final rejected = expectLater(first, foodFails(FoodScanFailure.cancelled));
    pending.complete(foodReply(testEstimate));
    await rejected;
  });
  test('Unidentifiable food has actionable error rather than fabricated values',
      () {
    expect(() => FoodEstimate.parse('{"unidentifiable":true}'),
        foodFails(FoodScanFailure.unidentifiable));
  });
  test('Zero macros accepted; unknown optional data stays absent', () {
    final result = FoodEstimate.parse(jsonEncode({...testEstimate, 'fat': 0}));
    expect(result.fat, 0);
    expect(result.portion, isNull);
    expect(result.items, isEmpty);
  });
}
