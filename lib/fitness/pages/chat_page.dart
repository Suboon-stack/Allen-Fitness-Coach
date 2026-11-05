import 'dart:math' as math;
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:allen/fitness/controllers/chat_controller.dart';
import 'package:allen/fitness/models/chat_message.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/gemini_chat_session.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.aiService});
  final AiService? aiService;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final ChatController _chat;
  bool _nearBottom = true, _following = false, _followScheduled = false;
  String? _composerError;

  String? _verifiedUser() {
    final auth = context.read<AuthCubit>();
    final state = auth.state;
    if (state is AuthLoading || state is AuthError && state.sessionUnresolved) {
      return null;
    }
    return auth.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    _chat = ChatController(
        service: widget.aiService ?? AiService(), userId: _verifiedUser())
      ..addListener(_conversationChanged);
    _input.addListener(_draftChanged);
    _scroll.addListener(_trackScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  void _conversationChanged() {
    if (mounted) {
      setState(() {});
      _scheduleFollow();
    }
  }

  void _draftChanged() {
    if (_composerError != null &&
        _input.text.trim().length <= GeminiChatSession.maxPromptCharacters) {
      setState(() => _composerError = null);
    }
    _scheduleFollow();
  }

  void _trackScroll() {
    if (!_following && _scroll.hasClients) {
      _nearBottom = _scroll.position.extentAfter <= 96;
    }
  }

  void _scheduleFollow() {
    if (!_nearBottom || _followScheduled) return;
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (!mounted || !_nearBottom || !_scroll.hasClients) return;
      _following = true;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      _following = false;
    });
  }

  @override
  void didChangeMetrics() {
    _scheduleFollow();
  }

  void _send() {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    // Check the current identity synchronously as well as through the listener.
    if (_verifiedUser() != _chat.userId) {
      _accountChanged();
      return;
    }
    final result = _chat.submit(_input.text);
    if (result == ChatSubmission.accepted) {
      _input.clear();
      setState(() => _composerError = null);
    } else if (result == ChatSubmission.tooLong) {
      setState(() =>
          _composerError = const ChatException(ChatFailure.tooLong).message);
    } else if (result == ChatSubmission.noSession) {
      setState(() => _composerError = 'Sign in to chat with Allen.');
    }
  }

  void _retry(int id) {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    if (_verifiedUser() != _chat.userId) {
      _accountChanged();
      return;
    }
    _chat.retry(id);
  }

  void _accountChanged() {
    final id = _verifiedUser();
    if (id == _chat.userId) return;
    _input.clear();
    _composerError = null;
    _nearBottom = true;
    _chat.resetForUser(id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_conversationChanged);
    _chat.dispose();
    _input.removeListener(_draftChanged);
    _input.dispose();
    _scroll.removeListener(_trackScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
      listener: (_, state) => _accountChanged(),
      child: AppThemeScope(child: Builder(builder: (context) {
        final theme = Theme.of(context),
            scale = MediaQuery.textScalerOf(context);
        final subtitleLines =
            MediaQuery.sizeOf(context).width < 400 && scale.scale(12) > 18
                ? 2
                : 1;
        final toolbar = math.max(64.0,
            scale.scale(20) * 1.3 + scale.scale(12) * 1.5 * subtitleLines + 12);
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) _chat.abandon();
          },
          child: Scaffold(
            appBar: AppBar(
                toolbarHeight: toolbar,
                titleSpacing: AppSpacing.md,
                title: Row(children: [
                  const AllenSparkle(),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text('Allen',
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text('AI Fitness Coach',
                            style: theme.textTheme.bodySmall,
                            maxLines: subtitleLines,
                            overflow: TextOverflow.ellipsis),
                      ])),
                ])),
            resizeToAvoidBottomInset: true,
            body: SafeArea(
                top: false,
                bottom: false,
                child: LayoutBuilder(
                    builder: (context, constraints) => Column(children: [
                          Expanded(
                              child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxWidth: AppLayout.contentWidth),
                                      child: _thread(context)))),
                          ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxHeight: constraints.maxHeight),
                              child: SingleChildScrollView(
                                  child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: AppLayout.contentWidth),
                                          child: _composer(context,
                                              constraints.maxHeight))))),
                        ]))),
          ),
        );
      })));

  Widget _thread(BuildContext context) {
    final messages = _chat.messages;
    if (messages.isEmpty) {
      return ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const SizedBox(height: AppSpacing.md),
            Text('Ask Allen', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            const Text(
                'Ideas for workouts, nutrition, and healthy routines. What’s on your mind?'),
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder<TextEditingValue>(
                valueListenable: _input,
                builder: (context, value, _) => Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final item in [
                            (
                              'Workout ideas',
                              'How can I build a balanced beginner workout routine?'
                            ),
                            (
                              'Nutrition basics',
                              'What are some practical ways to build balanced meals?'
                            ),
                            (
                              'Healthy routines',
                              'How can I make a consistent fitness routine?'
                            )
                          ])
                            ActionChip(
                                label: Text(item.$1),
                                onPressed:
                                    !_chat.hasSession || value.text.isNotEmpty
                                        ? null
                                        : () => _input.text = item.$2),
                        ])),
            const SizedBox(height: AppSpacing.lg),
            Text('Chats are temporary and aren’t saved in Allen.',
                style: Theme.of(context).textTheme.bodySmall),
            if (!_chat.hasSession)
              const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Text('Sign in to chat with Allen.')),
          ]);
    }
    return ListView.builder(
        key: const Key('chat-thread'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.md),
        itemCount: messages.length + (_chat.sending ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length) {
            return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Semantics(
                    liveRegion: true,
                    child: Text('Allen is thinking…',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.secondary))));
          }
          final message = messages[index];
          return CoachMessageBubble(
              key: ValueKey(message.id),
              message: message,
              onRetry:
                  _chat.canRetry(message.id) ? () => _retry(message.id) : null);
        });
  }

  Widget _composer(BuildContext context, double height) {
    final compact = height < 260;
    final maxLines = compact
        ? 1
        : height < 400 || MediaQuery.textScalerOf(context).scale(16) > 24
            ? 2
            : 4;
    return SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(
            AppSpacing.page,
            compact ? 4 : AppSpacing.sm,
            AppSpacing.page,
            compact ? 4 : AppSpacing.sm),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: TextField(
                        key: const Key('chat-input'),
                        controller: _input,
                        minLines: 1,
                        maxLines: maxLines,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        keyboardType: TextInputType.multiline,
                        onSubmitted: (_) => _send(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface),
                        decoration: const InputDecoration(
                            hintText: 'Message Allen',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: 8)))),
                const SizedBox(width: AppSpacing.sm),
                ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _input,
                    builder: (context, value, _) => Tooltip(
                        message: 'Send message',
                        excludeFromSemantics: true,
                        child: FilledButton(
                            key: const Key('chat-send'),
                            onPressed: _chat.sending ||
                                    !_chat.hasSession ||
                                    value.text.trim().isEmpty
                                ? null
                                : _send,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(52, 52),
                                padding: const EdgeInsets.all(12)),
                            child: const Icon(Icons.arrow_upward_rounded,
                                semanticLabel: 'Send message')))),
              ]),
              if (_composerError != null)
                Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(_composerError!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.error)))),
            ]));
  }
}
