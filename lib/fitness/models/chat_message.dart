enum ChatRole { user, assistant }

enum ChatMessageStatus { sending, sent, failed }

enum ChatFailure {
  empty,
  tooLong,
  busy,
  network,
  timeout,
  rateLimited,
  configuration,
  unavailable,
  blocked,
  malformed,
  truncated,
  cancelled
}

/// Only fixed app-owned messages cross the service/UI boundary.
class ChatException implements Exception {
  const ChatException(this.failure);
  final ChatFailure failure;
  String get message => switch (failure) {
        ChatFailure.empty => 'Write a message to Allen first.',
        ChatFailure.tooLong => 'Keep your message within 4,000 characters.',
        ChatFailure.busy =>
          'Wait for Allen’s current reply before sending again.',
        ChatFailure.network =>
          'Couldn’t reach Allen. Check your connection and retry.',
        ChatFailure.timeout => 'Allen took too long to reply. Please retry.',
        ChatFailure.rateLimited =>
          'Allen’s request limit has been reached. Wait a moment, then retry.',
        ChatFailure.configuration =>
          'Allen can’t connect to the AI service right now. Please try again later.',
        ChatFailure.unavailable =>
          'Allen is unavailable right now. Please try again shortly.',
        ChatFailure.blocked =>
          'Allen couldn’t answer this message. Try rephrasing your question.',
        ChatFailure.malformed =>
          'Allen returned an unreadable reply. Please retry.',
        ChatFailure.truncated => 'Allen’s reply was cut short. Please retry.',
        ChatFailure.cancelled => 'This request is no longer active.',
      };
  @override
  String toString() => message;
}

class ChatMessage {
  const ChatMessage(
      {required this.id,
      required this.role,
      required this.text,
      this.status = ChatMessageStatus.sent,
      this.failure});
  final int id;
  final ChatRole role;
  final String text;
  final ChatMessageStatus status;
  final ChatFailure? failure;
  ChatMessage withStatus(ChatMessageStatus value, {ChatFailure? error}) =>
      ChatMessage(
          id: id, role: role, text: text, status: value, failure: error);
}
