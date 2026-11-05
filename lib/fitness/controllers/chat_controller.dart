import 'dart:async';
import 'package:allen/fitness/models/chat_message.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/gemini_chat_session.dart';
import 'package:flutter/foundation.dart';

enum ChatSubmission { accepted, empty, tooLong, busy, noSession }

class ChatController extends ChangeNotifier {
  ChatController({required AiService service, required String? userId})
      : _service = service,
        _userId = userId {
    _service.clearHistory();
  }
  final AiService _service;
  String? _userId;
  final List<ChatMessage> _messages = [];
  bool _sending = false, _closed = false;
  int _generation = 0, _nextId = 0;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;
  bool get hasSession => !_closed && _userId != null;
  String? get userId => _userId;
  bool canRetry(int id) =>
      !_sending &&
      hasSession &&
      _messages.isNotEmpty &&
      _messages.last.id == id &&
      _messages.last.status == ChatMessageStatus.failed;

  ChatSubmission submit(String prompt) {
    if (_closed || !hasSession) return ChatSubmission.noSession;
    if (_sending) return ChatSubmission.busy;
    final text = prompt.trim();
    if (text.isEmpty) return ChatSubmission.empty;
    if (text.length > GeminiChatSession.maxPromptCharacters) {
      return ChatSubmission.tooLong;
    }
    final message = ChatMessage(
        id: _nextId++,
        role: ChatRole.user,
        text: text,
        status: ChatMessageStatus.sending);
    _messages.add(message);
    _start(message);
    return ChatSubmission.accepted;
  }

  bool retry(int id) {
    if (!canRetry(id)) return false;
    final message = _messages.last.withStatus(ChatMessageStatus.sending);
    _messages[_messages.length - 1] = message;
    _start(message);
    return true;
  }

  void _start(ChatMessage message) {
    _sending = true;
    final generation = ++_generation;
    final owner = _userId;
    notifyListeners();
    unawaited(_run(message, generation, owner));
  }

  Future<void> _run(ChatMessage message, int generation, String? owner) async {
    bool current() => !_closed && generation == _generation && owner == _userId;
    try {
      final text = await _service.chat(message.text);
      if (!current()) return;
      if (text.trim().isEmpty) throw const ChatException(ChatFailure.malformed);
      final index = _messages.indexWhere((m) => m.id == message.id);
      _messages[index] = message.withStatus(ChatMessageStatus.sent);
      _messages.add(
          ChatMessage(id: _nextId++, role: ChatRole.assistant, text: text));
    } catch (error) {
      if (!current()) return;
      final index = _messages.indexWhere((m) => m.id == message.id);
      _messages[index] = message.withStatus(ChatMessageStatus.failed,
          error:
              error is ChatException ? error.failure : ChatFailure.unavailable);
    } finally {
      if (current()) {
        _sending = false;
        notifyListeners();
      }
    }
  }

  void resetForUser(String? id) {
    if (_closed || id == _userId) return;
    _generation++;
    _userId = id;
    _messages.clear();
    _sending = false;
    _service.clearHistory();
    notifyListeners();
  }

  @override
  void dispose() {
    abandon();
    super.dispose();
  }

  /// Stop accepting replies as soon as navigation pops the route, before its
  /// transition finishes and Flutter disposes the widget.
  void abandon() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _service.clearHistory();
  }
}
