import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:allen/fitness/models/chat_message.dart';
import 'package:http/http.dart' as http;

/// Temporary context for one active conversation. Nothing is persisted.
class GeminiChatSession {
  GeminiChatSession(
      {required String apiKey,
      required this.prefix,
      http.Client? client,
      this.timeout = const Duration(seconds: 30)})
      : _apiKey = apiKey.trim(),
        _client = client;
  static const maxPromptCharacters = 4000;
  static const maxContextCharacters = 16000;
  static const maxHistoryTurns = 8;
  static const maxResponseCharacters = 12000;
  final String _apiKey;
  final List<Map<String, dynamic>> prefix;
  final http.Client? _client;
  final Duration timeout;
  final List<({String user, String assistant})> _turns = [];
  Object? _active;
  http.Client? _ownedClient;
  int _generation = 0;

  Future<String> send(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty) throw const ChatException(ChatFailure.empty);
    if (text.length > maxPromptCharacters) {
      throw const ChatException(ChatFailure.tooLong);
    }
    if (_active != null) throw const ChatException(ChatFailure.busy);
    if (_apiKey.isEmpty) throw const ChatException(ChatFailure.configuration);
    final token = Object(), generation = _generation;
    _active = token;
    final client = _client ?? http.Client();
    if (_client == null) _ownedClient = client;
    bool current() => generation == _generation && identical(_active, token);
    try {
      final contents = <Map<String, dynamic>>[...prefix];
      final history = List.of(_turns);
      final prefixSize = _prefixCharacters;
      if (prefixSize + text.length > maxContextCharacters) {
        throw const ChatException(ChatFailure.tooLong);
      }
      int historySize() => history.fold<int>(
          0, (n, t) => n + t.user.length + t.assistant.length);
      while (history.isNotEmpty &&
          (history.length > maxHistoryTurns ||
              prefixSize + historySize() + text.length >
                  maxContextCharacters)) {
        history.removeAt(0);
      }
      for (final turn in history) {
        contents.add(_content('user', turn.user));
        contents.add(_content('model', turn.assistant));
      }
      contents.add(_content('user', text));
      final response = await client
          .post(
              Uri.https(
                  'generativelanguage.googleapis.com',
                  '/v1beta/models/gemini-2.5-flash-lite:generateContent',
                  {'key': _apiKey}),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'contents': contents}))
          .timeout(timeout);
      if (!current()) throw const ChatException(ChatFailure.cancelled);
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        if (response.statusCode != 200) {
          throw _providerFailure(response.statusCode, null);
        }
        throw const ChatException(ChatFailure.malformed);
      }
      if (response.statusCode != 200 || data is Map && data['error'] != null) {
        throw _providerFailure(
            response.statusCode, data is Map ? data['error'] : null);
      }
      final reply = _reply(data);
      // A provider must never cause the app's configured credential to appear in
      // UI/history, even if it unexpectedly returns it in a success payload.
      if (reply.contains(_apiKey)) {
        throw const ChatException(ChatFailure.malformed);
      }
      if (!current()) throw const ChatException(ChatFailure.cancelled);
      _turns.add((user: text, assistant: reply));
      while (_turns.isNotEmpty &&
          (_turns.length > maxHistoryTurns ||
              _prefixCharacters +
                      _turns.fold<int>(
                          0, (n, t) => n + t.user.length + t.assistant.length) >
                  maxContextCharacters)) {
        _turns.removeAt(0);
      }
      return reply;
    } catch (error) {
      if (!current()) throw const ChatException(ChatFailure.cancelled);
      if (error is ChatException) rethrow;
      if (error is TimeoutException) {
        throw const ChatException(ChatFailure.timeout);
      }
      if (error is SocketException || error is http.ClientException) {
        throw const ChatException(ChatFailure.network);
      }
      throw const ChatException(ChatFailure.unavailable);
    } finally {
      if (_client == null) client.close();
      if (identical(_ownedClient, client)) _ownedClient = null;
      if (identical(_active, token)) _active = null;
    }
  }

  int get _prefixCharacters => prefix.fold<int>(
      0,
      (n, c) =>
          n +
          (c['parts'] as List)
              .fold<int>(0, (m, p) => m + (p['text'] as String).length));
  Map<String, dynamic> _content(String role, String text) => {
        'role': role,
        'parts': [
          {'text': text}
        ]
      };

  ChatException _providerFailure(int status, dynamic error) {
    if (status == 200 && error is Map && error['code'] is int) {
      status = error['code'] as int;
    }
    final provider = error is Map ? error['status'] : null;
    if (status == 429 || provider == 'RESOURCE_EXHAUSTED') {
      return const ChatException(ChatFailure.rateLimited);
    }
    if (status == 401 ||
        status == 403 ||
        provider == 'UNAUTHENTICATED' ||
        provider == 'PERMISSION_DENIED') {
      return const ChatException(ChatFailure.configuration);
    }
    if (status == 408 || status == 504 || provider == 'DEADLINE_EXCEEDED') {
      return const ChatException(ChatFailure.timeout);
    }
    return const ChatException(ChatFailure.unavailable);
  }

  String _reply(dynamic data) {
    if (data is! Map) throw const ChatException(ChatFailure.malformed);
    final feedback = data['promptFeedback'];
    if (feedback is Map &&
        feedback['blockReason'] != null &&
        feedback['blockReason'] != 'BLOCK_REASON_UNSPECIFIED') {
      throw const ChatException(ChatFailure.blocked);
    }
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
      throw const ChatException(ChatFailure.malformed);
    }
    final candidate = candidates.first as Map;
    final reason = candidate['finishReason'];
    if (reason == 'MAX_TOKENS') {
      throw const ChatException(ChatFailure.truncated);
    }
    if ([
      'SAFETY',
      'RECITATION',
      'BLOCKLIST',
      'PROHIBITED_CONTENT',
      'SPII',
      'IMAGE_SAFETY'
    ].contains(reason)) {
      throw const ChatException(ChatFailure.blocked);
    }
    if (reason != 'STOP') throw const ChatException(ChatFailure.malformed);
    final ratings = candidate['safetyRatings'];
    if (ratings is List &&
        ratings.any((r) => r is Map && r['blocked'] == true)) {
      throw const ChatException(ChatFailure.blocked);
    }
    final content = candidate['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw const ChatException(ChatFailure.malformed);
    }
    final visible = <String>[];
    for (final part in parts) {
      if (part is! Map) throw const ChatException(ChatFailure.malformed);
      if (part['thought'] == true) continue;
      if (part['text'] is! String) {
        throw const ChatException(ChatFailure.malformed);
      }
      visible.add(part['text'] as String);
    }
    final result = visible.join('\n').trim();
    if (result.isEmpty || result.length > maxResponseCharacters) {
      throw const ChatException(ChatFailure.malformed);
    }
    return result;
  }

  void reset() {
    _generation++;
    _turns.clear();
    _active = null;
    _ownedClient?.close();
    _ownedClient = null;
  }
}
