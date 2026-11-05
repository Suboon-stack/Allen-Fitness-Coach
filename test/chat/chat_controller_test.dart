import 'dart:async';
import 'package:allen/fitness/controllers/chat_controller.dart';
import 'package:allen/fitness/models/chat_message.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

class ControlledChatAi extends AiService {
  final prompts = <String>[];
  final pending = <Completer<String>>[];
  int resets = 0;
  @override
  Future<String> chat(String prompt) {
    prompts.add(prompt);
    final gate = Completer<String>();
    pending.add(gate);
    return gate.future;
  }

  @override
  void clearHistory() {
    resets++;
  }
}

Future<void> flushChat() => Future<void>.delayed(Duration.zero);

void main() {
  test(
      'Typed state is single-flight and successful replies complete the user turn',
      () async {
    final ai = ControlledChatAi();
    final controller = ChatController(service: ai, userId: 'member');
    addTearDown(controller.dispose);
    expect(controller.submit('Hello'), ChatSubmission.accepted);
    expect(controller.sending, isTrue);
    expect(controller.messages.single.status, ChatMessageStatus.sending);
    expect(controller.submit('Overlap'), ChatSubmission.busy);
    expect(ai.prompts, ['Hello']);
    ai.pending.single.complete('A useful reply');
    await flushChat();
    expect(controller.sending, isFalse);
    expect(controller.messages.map((m) => m.role),
        [ChatRole.user, ChatRole.assistant]);
    expect(controller.messages.first.status, ChatMessageStatus.sent);
    expect(() => controller.messages.clear(), throwsUnsupportedError);
  });
  test('Failure is explicit and retry reuses the same user message', () async {
    final ai = ControlledChatAi();
    final chat = ChatController(service: ai, userId: 'member');
    addTearDown(chat.dispose);
    chat.submit('Help with a routine');
    final id = chat.messages.single.id;
    ai.pending.first.completeError(const ChatException(ChatFailure.network));
    await flushChat();
    expect(chat.messages.single.failure, ChatFailure.network);
    expect(chat.canRetry(id), isTrue);
    expect(chat.retry(id), isTrue);
    expect(chat.retry(id), isFalse);
    expect(chat.messages.length, 1);
    ai.pending.last.complete('Try a simple routine.');
    await flushChat();
    expect(chat.messages.length, 2);
    expect(chat.messages.first.id, id);
    expect(ai.prompts.length, 2);
  });
  test(
      'Empty/long/no-session submissions preserve state without calling Gemini',
      () {
    final ai = ControlledChatAi();
    final chat = ChatController(service: ai, userId: null);
    addTearDown(chat.dispose);
    expect(chat.submit('Hello'), ChatSubmission.noSession);
    chat.resetForUser('member');
    expect(chat.submit('  '), ChatSubmission.empty);
    expect(chat.submit('x' * 4001), ChatSubmission.tooLong);
    expect(chat.messages, isEmpty);
    expect(ai.prompts, isEmpty);
  });
  test(
      'Account reset rejects old replies even when switching back to the same UID',
      () async {
    final ai = ControlledChatAi();
    final chat = ChatController(service: ai, userId: 'a');
    addTearDown(chat.dispose);
    chat.submit('Old question');
    chat.resetForUser('b');
    chat.resetForUser('a');
    chat.submit('New question');
    ai.pending.first.complete('Old reply');
    await flushChat();
    expect(chat.messages.single.text, 'New question');
    expect(chat.sending, isTrue);
    ai.pending.last.complete('New reply');
    await flushChat();
    expect(chat.messages.last.text, 'New reply');
    expect(ai.resets, 3);
  });
  test('Disposal ignores late completions and clears the service context',
      () async {
    final ai = ControlledChatAi();
    final chat = ChatController(service: ai, userId: 'member');
    var notifications = 0;
    chat.addListener(() => notifications++);
    chat.submit('Pending');
    chat.dispose();
    final before = notifications;
    ai.pending.single.complete('Late');
    await flushChat();
    expect(notifications, before);
    expect(ai.resets, 2);
  });
  test(
      'Unexpected failures are sanitized and an older failed message cannot reorder later context',
      () async {
    final ai = ControlledChatAi();
    final chat = ChatController(service: ai, userId: 'member');
    addTearDown(chat.dispose);
    chat.submit('First');
    ai.pending.first.completeError(StateError('private url key=dummy-secret'));
    await flushChat();
    final failed = chat.messages.single;
    expect(ChatException(failed.failure!).message, isNot(contains('private')));
    chat.submit('Continue');
    ai.pending.last.complete('Actual answer');
    await flushChat();
    expect(chat.canRetry(failed.id), isFalse);
    expect(chat.retry(failed.id), isFalse);
  });
  test(
      'Navigation abandonment rejects replies before disposal and new submissions',
      () async {
    final ai = ControlledChatAi();
    final chat = ChatController(service: ai, userId: 'member');
    chat.submit('Leaving');
    var notifications = 0;
    chat.addListener(() => notifications++);
    chat.abandon();
    ai.pending.single.complete('Late reply');
    await flushChat();
    expect(notifications, 0);
    expect(chat.submit('Another'), ChatSubmission.noSession);
    expect(chat.messages.length, 1);
    chat.dispose();
    expect(ai.resets, 2);
  });
  test('A failed message cannot be retried after navigation abandonment',
      () async {
    final ai = ControlledChatAi();
    final chat = ChatController(service: ai, userId: 'member');
    chat.submit('Leaving after failure');
    ai.pending.single.completeError(const ChatException(ChatFailure.network));
    await flushChat();
    final id = chat.messages.single.id;
    expect(chat.canRetry(id), isTrue);
    chat.abandon();
    expect(chat.canRetry(id), isFalse);
    expect(chat.retry(id), isFalse);
    expect(ai.prompts.length, 1);
    chat.dispose();
  });
}
