import 'dart:async';
import 'dart:convert';
import 'package:allen/fitness/models/chat_message.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/gemini_chat_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _key = 'dummy-chat-credential';
http.Response reply(String text, {String reason = 'STOP'}) => http.Response(
    jsonEncode({
      'candidates': [
        {
          'finishReason': reason,
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    }),
    200);
Matcher fails(ChatFailure failure) => throwsA(
    isA<ChatException>().having((e) => e.failure, 'safe failure', failure));
GeminiChatSession session(http.Client client,
        {Duration timeout = const Duration(seconds: 30)}) =>
    GeminiChatSession(
        apiKey: _key,
        client: client,
        timeout: timeout,
        prefix: const [
          {
            'role': 'user',
            'parts': [
              {'text': 'Help with fitness.'}
            ]
          },
          {
            'role': 'model',
            'parts': [
              {'text': 'Understood.'}
            ]
          },
        ]);
List<dynamic> contents(http.Request request) =>
    jsonDecode(request.body)['contents'] as List;

void main() {
  test(
      'AiService chat preserves real multipart text and successful context, without keyword error detection',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      requests.add(r);
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'finishReason': 'STOP',
                'content': {
                  'parts': [
                    {'text': 'Your daily quota is a planning preference.'},
                    {'text': 'Try these 429 practical steps.'}
                  ]
                }
              }
            ]
          }),
          200);
    });
    addTearDown(client.close);
    final ai = AiService(client: client);
    expect(await ai.chat('  Build a routine  '), contains('\nTry these 429'));
    await ai.chat('Explain more');
    expect(requests.first.url.path,
        contains('gemini-2.5-flash-lite:generateContent'));
    expect(
        contents(requests.first).last['parts'][0]['text'], 'Build a routine');
    expect(contents(requests.last).length, 5);
    expect(contents(requests.last)[3]['role'], 'model');
  });
  final cases = <String, ({dynamic data, ChatFailure error})>{
    'empty root': (data: {}, error: ChatFailure.malformed),
    'wrong root': (data: [], error: ChatFailure.malformed),
    'no candidates': (data: {'candidates': []}, error: ChatFailure.malformed),
    'wrong candidate': (
      data: {
        'candidates': ['wrong']
      },
      error: ChatFailure.malformed
    ),
    'blocked prompt': (
      data: {
        'promptFeedback': {'blockReason': 'SAFETY'}
      },
      error: ChatFailure.blocked
    ),
    'blocked candidate': (
      data: {
        'candidates': [
          {'finishReason': 'SAFETY'}
        ]
      },
      error: ChatFailure.blocked
    ),
    'truncated': (
      data: {
        'candidates': [
          {
            'finishReason': 'MAX_TOKENS',
            'content': {
              'parts': [
                {'text': 'Partial'}
              ]
            }
          }
        ]
      },
      error: ChatFailure.truncated
    ),
    'missing finish reason': (
      data: {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Incomplete'}
              ]
            }
          }
        ]
      },
      error: ChatFailure.malformed
    ),
    'missing parts': (
      data: {
        'candidates': [
          {'finishReason': 'STOP', 'content': {}}
        ]
      },
      error: ChatFailure.malformed
    ),
    'empty text': (
      data: {
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {'text': '  '}
              ]
            }
          }
        ]
      },
      error: ChatFailure.malformed
    ),
    'wrong text type': (
      data: {
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {'text': 123}
              ]
            }
          }
        ]
      },
      error: ChatFailure.malformed
    ),
    'blocked rating': (
      data: {
        'candidates': [
          {
            'finishReason': 'STOP',
            'safetyRatings': [
              {'blocked': true}
            ],
            'content': {
              'parts': [
                {'text': 'Hidden'}
              ]
            }
          }
        ]
      },
      error: ChatFailure.blocked
    ),
    'structured provider status': (
      data: {
        'error': {
          'status': 'RESOURCE_EXHAUSTED',
          'message': 'private provider text'
        }
      },
      error: ChatFailure.rateLimited
    ),
    'structured provider code': (
      data: {
        'error': {'code': 429, 'message': 'private provider text'}
      },
      error: ChatFailure.rateLimited
    ),
  };
  for (final entry in cases.entries) {
    test('Validates ${entry.key}', () async {
      final client = MockClient(
          (_) async => http.Response(jsonEncode(entry.value.data), 200));
      addTearDown(client.close);
      await expectLater(
          session(client).send('Hello'), fails(entry.value.error));
    });
  }
  for (final entry in {
    400: ChatFailure.unavailable,
    401: ChatFailure.configuration,
    403: ChatFailure.configuration,
    408: ChatFailure.timeout,
    429: ChatFailure.rateLimited,
    500: ChatFailure.unavailable,
    503: ChatFailure.unavailable,
    504: ChatFailure.timeout
  }.entries) {
    test('HTTP ${entry.key} is sanitized and never auto-retried', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
            '{"error":{"message":"$_key private provider detail https://example.invalid/?key=$_key"}}',
            entry.key);
      });
      addTearDown(client.close);
      await expectLater(session(client).send('Hello'), fails(entry.value));
      expect(calls, 1);
    });
  }
  test(
      'Malformed JSON, non-JSON errors and credential-bearing success are rejected safely',
      () async {
    for (final response in [
      http.Response('bad-json', 200),
      http.Response('<private failure>', 500),
      reply(_key)
    ]) {
      final client = MockClient((_) async => response);
      addTearDown(client.close);
      await expectLater(
          session(client).send('Hello'),
          throwsA(isA<ChatException>().having(
              (e) => e.toString(),
              'redacted',
              allOf(isNot(contains(_key)), isNot(contains('private')),
                  isNot(contains('http'))))));
    }
  });
  test(
      'Network and unexpected exceptions never expose their URL/key or print logs',
      () async {
    final printed = <String>[];
    await runZoned(() async {
      for (final error in [
        http.ClientException(
            'private detail', Uri.parse('https://example.invalid/?key=$_key')),
        StateError('private $_key')
      ]) {
        final client = MockClient((_) async => throw error);
        addTearDown(client.close);
        await expectLater(
            session(client).send('Hello'),
            throwsA(isA<ChatException>().having(
                (e) => e.message,
                'sanitized',
                allOf(isNot(contains(_key)), isNot(contains('private')),
                    isNot(contains('uri='))))));
      }
    },
        zoneSpecification:
            ZoneSpecification(print: (_, __, ___, line) => printed.add(line)));
    expect(printed, isEmpty);
  });
  test('Timeout releases sending state and a late reply never enters context',
      () async {
    final pending = Completer<http.Response>();
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      requests.add(r);
      return requests.length == 1 ? await pending.future : reply('New reply');
    });
    addTearDown(client.close);
    final chat = session(client, timeout: const Duration(milliseconds: 1));
    await expectLater(chat.send('Timed out'), fails(ChatFailure.timeout));
    pending.complete(reply('Too late'));
    await Future<void>.delayed(Duration.zero);
    await chat.send('Fresh request');
    expect(contents(requests.last).length, 3);
  });
  test('Overlapping sends are rejected before making another HTTP request',
      () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((_) {
      calls++;
      return pending.future;
    });
    addTearDown(client.close);
    final chat = session(client);
    final first = chat.send('First');
    await expectLater(chat.send('Second'), fails(ChatFailure.busy));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    pending.complete(reply('Answer'));
    await first;
  });
  test(
      'Reset invalidates old responses without clearing a newer active request',
      () async {
    final old = Completer<http.Response>(), newer = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((_) {
      calls++;
      return calls == 1 ? old.future : newer.future;
    });
    addTearDown(client.close);
    final chat = session(client);
    final first = chat.send('Account A');
    chat.reset();
    final second = chat.send('Account B');
    final oldFailure = expectLater(first, fails(ChatFailure.cancelled));
    old.complete(reply('Old reply'));
    await oldFailure;
    await expectLater(chat.send('Overlapping'), fails(ChatFailure.busy));
    newer.complete(reply('Current reply'));
    expect(await second, 'Current reply');
  });
  test(
      'Failed turns never enter successful context and retry includes the prompt exactly once',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      requests.add(r);
      return requests.length == 2
          ? http.Response('{}', 503)
          : reply('Actual reply');
    });
    addTearDown(client.close);
    final chat = session(client);
    await chat.send('First');
    await expectLater(
        chat.send('Failed prompt'), fails(ChatFailure.unavailable));
    await chat.send('Failed prompt');
    final texts = contents(requests.last).map((c) => c['parts'][0]['text']);
    expect(texts.where((t) => t == 'Failed prompt').length, 1);
    expect(texts, contains('First'));
    expect(contents(requests.last).length, 5);
  });
  test(
      'Context keeps at most eight complete turns and respects the character budget',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      requests.add(r);
      return reply('Answer ${requests.length}');
    });
    addTearDown(client.close);
    final chat = session(client);
    for (var i = 0; i < 20; i++) {
      await chat.send('Question $i');
    }
    final sent = contents(requests.last);
    expect(sent.length, lessThanOrEqualTo(2 + 16 + 1));
    expect(sent[2]['parts'][0]['text'], 'Question 11');
    expect(sent.last['parts'][0]['text'], 'Question 19');
    final largeRequests = <http.Request>[];
    final largeClient = MockClient((r) async {
      largeRequests.add(r);
      return reply('a' * 3500);
    });
    addTearDown(largeClient.close);
    final large = session(largeClient);
    for (var i = 0; i < 8; i++) {
      await large.send('q' * 1800);
    }
    for (final request in largeRequests) {
      final c = contents(request);
      final chars = c.fold<int>(
          0, (n, e) => n + (e['parts'][0]['text'] as String).length);
      expect(chars, lessThanOrEqualTo(GeminiChatSession.maxContextCharacters));
      expect((c.length - 3) % 2, 0);
    }
  });
  test(
      'Empty, oversized prompts and oversized replies are rejected without fabricated defaults',
      () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return reply('a' * (GeminiChatSession.maxResponseCharacters + 1));
    });
    addTearDown(client.close);
    final chat = session(client);
    await expectLater(chat.send('   '), fails(ChatFailure.empty));
    await expectLater(chat.send('x' * 4001), fails(ChatFailure.tooLong));
    expect(calls, 0);
    await expectLater(chat.send('Hello'), fails(ChatFailure.malformed));
  });
  test('Chat context is never included in workout, meal or quote requests',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      requests.add(r);
      return reply('Actual provider text');
    });
    addTearDown(client.close);
    final ai = AiService(client: client);
    await ai.chat('Private chat context');
    await ai.generateWorkout(
        muscleGroup: 'Chest', difficulty: 'Beginner', duration: '20 min');
    await ai.generateMealPlan(
        goal: 'Maintain', diet: 'No preference', calories: 2000);
    await ai.getDailyQuote();
    for (final request in requests.skip(1)) {
      expect(contents(request).length, 3);
      expect(request.body, isNot(contains('Private chat context')));
    }
  });
  test('Thought parts are excluded from visible responses', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'candidates': [
            {
              'finishReason': 'STOP',
              'content': {
                'parts': [
                  {'thought': true, 'text': 'Not a visible answer'},
                  {'text': 'A visible answer'}
                ]
              }
            }
          ]
        }),
        200));
    addTearDown(client.close);
    expect(await session(client).send('Hello'), 'A visible answer');
  });
}
