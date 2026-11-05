import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/pages/chat_page.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/fake_auth_repo.dart';
import 'chat_controller_test.dart' show ControlledChatAi;

void main() {
  late ControlledChatAi ai;
  late FakeAuthRepo repo;
  late AuthCubit auth;
  setUp(() async {
    ai = ControlledChatAi();
    repo = FakeAuthRepo()
      ..user = AppUser(uid: 'member', email: 'member@example.com');
    auth = AuthCubit(authRepo: repo);
    await auth.checkAuth();
  });
  tearDown(() async {
    await auth.close();
  });
  final input = find.byKey(const Key('chat-input'));
  final send = find.byKey(const Key('chat-send'));
  Finder selectable(String text) => find.byWidgetPredicate((w) =>
      w is SelectableText && (w.data ?? w.textSpan?.toPlainText()) == text);
  Future<void> pump(WidgetTester tester,
      {double scale = 1,
      Brightness brightness = Brightness.dark,
      bool reduce = false,
      bool route = false}) async {
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.legacyTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    platformBrightness: brightness,
                    disableAnimations: reduce),
                child: child!),
            home: route
                ? Builder(
                    builder: (context) => Scaffold(
                        body: TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => ChatPage(aiService: ai))),
                            child: const Text('Open chat'))))
                : ChatPage(aiService: ai))));
    await tester.pumpAndSettle();
    if (route) {
      await tester.tap(find.text('Open chat'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(input, text);
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Header uses original sparkle and Midnight; suggestions populate without sending',
      (tester) async {
    await pump(tester);
    expect(find.text('Allen'), findsOneWidget);
    expect(find.text('AI Fitness Coach'), findsOneWidget);
    expect(find.byType(AllenSparkle), findsOneWidget);
    expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        AppColors.background);
    expect(find.text('Ask Allen'), findsOneWidget);
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.tap(find.widgetWithText(ActionChip, 'Nutrition basics'));
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text,
        contains('balanced meals'));
    expect(ai.prompts, isEmpty);
    expect(
        tester
            .widget<ActionChip>(
                find.widgetWithText(ActionChip, 'Workout ideas'))
            .onPressed,
        isNull);
  });
  testWidgets(
      'Send is accessible and pending request blocks button and keyboard duplicates without clearing a draft',
      (tester) async {
    await pump(tester);
    await submit(tester, 'First question');
    expect(ai.prompts, ['First question']);
    expect(find.text('Allen is thinking…'), findsOneWidget);
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.enterText(input, 'My next draft');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(ai.prompts.length, 1);
    expect(tester.widget<TextField>(input).controller!.text, 'My next draft');
    ai.pending.single.complete('A useful answer.');
    await tester.pumpAndSettle();
    expect(find.text('Allen is thinking…'), findsNothing);
    expect(selectable('A useful answer.'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller!.text, 'My next draft');
    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    handle.dispose();
  });
  testWidgets(
      'Failure is sanitized and Retry preserves the user bubble and unsent draft',
      (tester) async {
    await pump(tester);
    await submit(tester, 'Question');
    await tester.enterText(input, 'Next draft');
    ai.pending.single.completeError(
        StateError('private https://example.invalid/?key=dummy-secret'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(selectable('Question'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(ai.prompts.length, 2);
    expect(selectable('Question'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller!.text, 'Next draft');
    ai.pending.last.complete('Recovered');
    await tester.pumpAndSettle();
    expect(selectable('Recovered'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
  testWidgets('Oversized input remains editable and is never submitted',
      (tester) async {
    await pump(tester);
    final draft = 'x' * 4001;
    await submit(tester, draft);
    expect(ai.prompts, isEmpty);
    expect(tester.widget<TextField>(input).controller!.text, draft);
    expect(find.text('Keep your message within 4,000 characters.'),
        findsOneWidget);
  });
  testWidgets(
      'Leaving a pending chat ignores late completion and returning starts fresh',
      (tester) async {
    await pump(tester, route: true);
    await submit(tester, 'Pending');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    ai.pending.single.complete('Too late');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();
    expect(selectable('Pending'), findsNothing);
    expect(selectable('Too late'), findsNothing);
    expect(find.text('Ask Allen'), findsOneWidget);
  });
  testWidgets(
      'Account changes clear messages/draft and reject old account replies',
      (tester) async {
    await pump(tester);
    await submit(tester, 'Old account');
    await tester.enterText(input, 'Private draft');
    repo.user = AppUser(uid: 'other', email: 'other@example.com');
    await auth.checkAuth();
    await tester.pumpAndSettle();
    expect(find.text('Ask Allen'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    ai.pending.first.complete('Old response');
    await tester.pumpAndSettle();
    expect(selectable('Old response'), findsNothing);
    await submit(tester, 'New account');
    ai.pending.last.complete('New response');
    await tester.pumpAndSettle();
    expect(selectable('New response'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('An unavailable session preserves typed input and sends nothing',
      (tester) async {
    await auth.logout();
    await pump(tester);
    await tester.enterText(input, 'Keep this draft');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(ai.prompts, isEmpty);
    expect(tester.widget<TextField>(input).controller!.text, 'Keep this draft');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
  });
  testWidgets(
      'Basic formatting is selectable text and cannot load images or execute markup',
      (tester) async {
    const source =
        '## Routine\n\n- **Warm up** first\n1. Walk for a few minutes\n\n<script>literal text</script>\n`code`';
    await pump(tester);
    await submit(tester, 'Routine');
    ai.pending.single.complete(source);
    await tester.pumpAndSettle();
    final reply = tester.widget<SelectableText>(find.descendant(
        of: find.byType(CoachReply), matching: find.byType(SelectableText)));
    final text = reply.textSpan!.toPlainText();
    expect(text, contains('• Warm up first'));
    expect(text, contains('1. Walk'));
    expect(text, contains('<script>literal text</script>'));
    expect(text, isNot(contains('**')));
    expect(find.byType(Image), findsNothing);
  });
  testWidgets(
      'Following a reply does not move the viewport while reading earlier messages',
      (tester) async {
    await pump(tester);
    for (var i = 0; i < 8; i++) {
      await submit(tester, 'Question $i');
      ai.pending.last.complete(
          List.filled(8, 'A useful paragraph for response $i.').join('\n\n'));
      await tester.pumpAndSettle();
    }
    await submit(tester, 'Waiting');
    final thread = find.byKey(const Key('chat-thread'));
    await tester.drag(thread, const Offset(0, 600));
    await tester.pumpAndSettle();
    final state = tester.state<ScrollableState>(
        find.descendant(of: thread, matching: find.byType(Scrollable)).first);
    final before = state.position.pixels;
    expect(state.position.extentAfter, greaterThan(96));
    ai.pending.last.complete('A new reply');
    await tester.pumpAndSettle();
    expect(state.position.pixels, closeTo(before, 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Near-bottom replies remain visible after layout and composer growth is bounded',
      (tester) async {
    await pump(tester);
    await submit(tester, 'Question');
    ai.pending.last
        .complete(List.filled(30, 'A useful long paragraph.').join('\n\n'));
    await tester.pumpAndSettle();
    final thread = find.byKey(const Key('chat-thread'));
    final state = tester.state<ScrollableState>(
        find.descendant(of: thread, matching: find.byType(Scrollable)).first);
    expect(state.position.extentAfter, lessThanOrEqualTo(2));
    await tester.enterText(input, List.filled(30, 'A draft line').join('\n'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).maxLines, lessThanOrEqualTo(4));
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(800, 400)
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'Chat supports $size, 200% text, $brightness, keyboard and reduced motion',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPadding);
        await pump(tester,
            scale: 2, brightness: brightness, reduce: true, route: true);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pumpAndSettle();
        await tester.enterText(input, 'Help with healthy routines');
        await tester.pump();
        expect(send.hitTestable(), findsOneWidget);
        await tester.tap(send);
        await tester.pumpAndSettle();
        ai.pending.single.complete(
            '**Start small.**\n\n- Pick one habit\n- Keep it consistent');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(send.hitTestable(), findsOneWidget);
      });
    }
  }
}
