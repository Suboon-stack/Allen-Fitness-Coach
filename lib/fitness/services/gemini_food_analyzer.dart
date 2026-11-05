import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/food_estimate.dart';

/// Uses the existing client-side Gemini architecture. Does not retain images or
/// add chat context. Cancellation invalidates replies and closes owned transport.
class GeminiFoodAnalyzer {
  GeminiFoodAnalyzer(
      {required String apiKey,
      http.Client? client,
      this.timeout = const Duration(seconds: 30)})
      : _key = apiKey.trim(),
        _client = client;
  final String _key;
  final http.Client? _client;
  final Duration timeout;
  Object? _active;
  http.Client? _owned;
  static const maxImageBytes = 8 * 1024 * 1024;

  Future<FoodEstimate> analyze(File file) async {
    if (_active != null) throw const FoodScanException(FoodScanFailure.busy);
    final token = Object();
    _active = token;
    final client = _client ?? http.Client();
    if (_client == null) _owned = client;
    bool current() => identical(_active, token);
    try {
      return await (() async {
        if (_key.isEmpty) {
          throw const FoodScanException(FoodScanFailure.configuration);
        }
        Uint8List bytes;
        try {
          if (await file.length() > maxImageBytes) {
            throw const FormatException();
          }
          bytes = await file.readAsBytes();
        } catch (_) {
          throw const FoodScanException(FoodScanFailure.image);
        }
        final mime = _mime(bytes);
        if (!current()) {
          throw const FoodScanException(FoodScanFailure.cancelled);
        }
        final response = await client.post(
            Uri.https(
                'generativelanguage.googleapis.com',
                '/v1beta/models/gemini-2.5-flash-lite:generateContent',
                {'key': _key}),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {
                      'inline_data': {
                        'mime_type': mime,
                        'data': base64Encode(bytes)
                      }
                    },
                    {
                      'text':
                          '''Estimate nutrition for the entire visible food portion. Return only one JSON object:
{"foodName":"food name","calories":560,"protein":42,"carbs":56,"fat":14,"portion":"optional supported portion estimate","items":[{"name":"identified food","portion":"optional supported portion"}],"tip":"optional brief general food tip"}
All numbers are estimates, not verified facts. Calories must be a nonnegative integer in kcal; macros are nonnegative grams for the entire portion.
Do not copy example values. Include items and portions only when identifiable from this image; omit unsupported optional fields. Never invent ingredients or quantities.
If no food can be identified, return {"unidentifiable":true} instead of inventing nutrition. Do not include medical claims or other text.'''
                    }
                  ]
                }
              ],
              'generationConfig': {'responseMimeType': 'application/json'},
            }));
        if (!current()) {
          throw const FoodScanException(FoodScanFailure.cancelled);
        }
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          if (response.statusCode != 200) {
            throw _failure(response.statusCode, null);
          }
          throw const FoodScanException(FoodScanFailure.malformed);
        }
        if (response.statusCode != 200 ||
            data is Map && data['error'] != null) {
          throw _failure(
              response.statusCode, data is Map ? data['error'] : null);
        }
        final text = _text(data);
        if (text.contains(_key)) {
          throw const FoodScanException(FoodScanFailure.malformed);
        }
        final result = FoodEstimate.parse(text);
        if (!current()) {
          throw const FoodScanException(FoodScanFailure.cancelled);
        }
        return result;
      })()
          .timeout(timeout);
    } catch (error) {
      if (!current()) throw const FoodScanException(FoodScanFailure.cancelled);
      if (error is FoodScanException) rethrow;
      if (error is TimeoutException) {
        throw const FoodScanException(FoodScanFailure.timeout);
      }
      if (error is SocketException || error is http.ClientException) {
        throw const FoodScanException(FoodScanFailure.network);
      }
      throw const FoodScanException(FoodScanFailure.unavailable);
    } finally {
      if (_client == null) client.close();
      if (identical(_owned, client)) _owned = null;
      if (current()) _active = null;
    }
  }

  String _mime(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const FoodScanException(FoodScanFailure.image);
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    throw const FoodScanException(FoodScanFailure.image);
  }

  FoodScanException _failure(int status, dynamic error) {
    if (status == 200 && error is Map && error['code'] is int) {
      status = error['code'];
    }
    final code = error is Map ? error['status'] : null;
    final details = error is Map ? error['details'] : null;
    final credentialFailure = details is List &&
        details.any((detail) =>
            detail is Map &&
            [
              'API_KEY_INVALID',
              'API_KEY_EXPIRED',
              'API_KEY_SERVICE_BLOCKED',
              'API_KEY_HTTP_REFERRER_BLOCKED',
              'API_KEY_IP_ADDRESS_BLOCKED',
              'SERVICE_DISABLED'
            ].contains(detail['reason']));
    if (status == 429 || code == 'RESOURCE_EXHAUSTED') {
      return const FoodScanException(FoodScanFailure.rateLimited);
    }
    if (credentialFailure ||
        [401, 403].contains(status) ||
        ['UNAUTHENTICATED', 'PERMISSION_DENIED'].contains(code)) {
      return const FoodScanException(FoodScanFailure.configuration);
    }
    if ([408, 504].contains(status) || code == 'DEADLINE_EXCEEDED') {
      return const FoodScanException(FoodScanFailure.timeout);
    }
    if (status == 400 || code == 'INVALID_ARGUMENT') {
      return const FoodScanException(FoodScanFailure.image);
    }
    return const FoodScanException(FoodScanFailure.unavailable);
  }

  String _text(dynamic data) {
    const invalid = FoodScanException(FoodScanFailure.malformed);
    if (data is! Map) throw invalid;
    final feedback = data['promptFeedback'];
    if (feedback is Map &&
        feedback['blockReason'] != null &&
        feedback['blockReason'] != 'BLOCK_REASON_UNSPECIFIED') {
      throw const FoodScanException(FoodScanFailure.blocked);
    }
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
      throw invalid;
    }
    final candidate = candidates.first as Map;
    final reason = candidate['finishReason'];
    if (reason == 'MAX_TOKENS') {
      throw const FoodScanException(FoodScanFailure.truncated);
    }
    if ([
      'SAFETY',
      'RECITATION',
      'BLOCKLIST',
      'PROHIBITED_CONTENT',
      'SPII',
      'IMAGE_SAFETY'
    ].contains(reason)) {
      throw const FoodScanException(FoodScanFailure.blocked);
    }
    final ratings = candidate['safetyRatings'];
    if (ratings is List &&
        ratings.any((r) => r is Map && r['blocked'] == true)) {
      throw const FoodScanException(FoodScanFailure.blocked);
    }
    if (reason != 'STOP') throw invalid;
    final content = candidate['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) throw invalid;
    final texts = <String>[];
    for (final part in parts) {
      if (part is! Map) throw invalid;
      if (part['thought'] == true) continue;
      if (part['text'] is! String) throw invalid;
      texts.add(part['text']);
    }
    final text = texts.join('\n').trim();
    if (text.isEmpty || text.length > 20000) throw invalid;
    return text;
  }

  void cancel() {
    _active = null;
    _owned?.close();
    _owned = null;
  }
}
