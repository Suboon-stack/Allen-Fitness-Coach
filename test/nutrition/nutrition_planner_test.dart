import 'dart:async';
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/pages/meal_planner_page.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/meal_plan_parser.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/tracker_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/fake_auth_repo.dart';
import 'meal_plan_parser_test.dart' show fullPlan;

class _Ai extends AiService {
  String response = fullPlan;
  Object? failure;
  Completer<String>? pending;
  int calls = 0;
  @override
  Future<String> generateMealPlan(
      {required String goal,
      required String diet,
      required int calories}) async {
    calls++;
    if (failure != null) throw failure!;
    return pending == null ? response : await pending!.future;
  }
}

class _Repo extends MealRepository {
  Completer<void>? pending;
  bool fail = false;
  bool failAfterWrite = false;
  final ids = <String>[];
  @override
  Future<String> createMeal(Meal meal) async {
    ids.add(meal.id);
    if (pending != null) await pending!.future;
    if (fail) throw StateError('private native error');
    final id = await super.createMeal(meal);
    if (failAfterWrite) {
      failAfterWrite = false;
      throw StateError('confirmation lost');
    }
    return id;
  }
}

void main() {
  late _Ai ai;
  late _Repo repo;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ai = _Ai();
    repo = _Repo();
  });
  Future<void> pumpPlanner(WidgetTester tester,
      {double scale = 1, Brightness brightness = Brightness.dark}) async {
    final auth = AuthCubit(
        authRepo: FakeAuthRepo()
          ..user = AppUser(uid: 'member', email: 'member@example.com'));
    await auth.checkAuth();
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.legacyTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    platformBrightness: brightness),
                child: child!),
            home: MealPlannerPage(aiService: ai, repository: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Planner'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final f = find.text(label).last;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    await tap(tester, 'Generate meal plan');
  }

  Future<void> review(WidgetTester tester) async {
    final f = find.text('Review & log meal').first;
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Single generation request shows loading and preserves supplied estimates',
      (tester) async {
    ai.pending = Completer<String>();
    await pumpPlanner(tester);
    final button = find.widgetWithText(FilledButton, 'Generate meal plan');
    await tester.ensureVisible(button);
    final action = tester.widget<FilledButton>(button).onPressed!;
    action();
    action();
    await tester.pump();
    expect(ai.calls, 1);
    expect(find.text('Planning your meals…'), findsOneWidget);
    expect(
        tester
            .widget<DropdownButtonFormField<int>>(
                find.byKey(const Key('meal-calorie-target')))
            .onChanged,
        isNull);
    ai.pending!.complete(fullPlan);
    await tester.pumpAndSettle();
    expect(find.text('Oats'), findsOneWidget);
    expect(find.textContaining('1700 kcal'), findsOneWidget);
    expect(await repo.getUserMeals('member'), isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Failed regeneration preserves valid suggestions and offers retry',
      (tester) async {
    await pumpPlanner(tester);
    await generate(tester);
    ai.failure =
        const MealGenerationException('Allen is unavailable. Please retry.');
    await tap(tester, 'Generate another plan');
    expect(find.text('Oats'), findsOneWidget);
    expect(find.textContaining('Allen is unavailable'), findsOneWidget);
    ai.failure = null;
    ai.response = 'invalid plan';
    await tap(tester, 'Try generating again');
    expect(find.text('Oats'), findsOneWidget);
    expect(find.textContaining('incomplete or unreadable'), findsOneWidget);
    ai.response = fullPlan;
    await tap(tester, 'Try generating again');
    expect(find.text('Generate another plan'), findsOneWidget);
  });
  testWidgets('Review edits are saved once and update the recorded summary',
      (tester) async {
    await pumpPlanner(tester);
    await generate(tester);
    await review(tester);
    await tester.enterText(
        find.byKey(const Key('review-meal-name')), 'My oats');
    await tester.enterText(
        find.byKey(const ValueKey('review-Calories (kcal)')), '450');
    repo.pending = Completer<void>();
    final button = find.widgetWithText(FilledButton, 'Log meal for today');
    await tester.ensureVisible(button);
    final action = tester.widget<FilledButton>(button).onPressed!;
    action();
    action();
    await tester.pump();
    expect(repo.ids.length, 1);
    expect(find.text('Logging meal…'), findsOneWidget);
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Logged today'), findsOneWidget);
    expect((await repo.getUserMeals('member')).single.name, 'My oats');
    expect((await repo.getDailyNutrition('member', DateTime.now()))['calories'],
        450);
    await tester.tap(find.widgetWithText(Tab, 'Tracker'));
    await tester.pumpAndSettle();
    expect(find.text('My oats'), findsOneWidget);
    final ring = tester
        .widget<TrackerProgress>(find.byKey(const Key('calorie-progress')));
    expect(ring.value, 450);
    expect(ring.goal, isNull);
  });
  testWidgets('Uncertain save retry keeps form values and reuses its UUID',
      (tester) async {
    await pumpPlanner(tester);
    await generate(tester);
    await review(tester);
    await tester.enterText(
        find.byKey(const Key('review-meal-name')), 'Reviewed oats');
    repo.failAfterWrite = true;
    await tap(tester, 'Log meal for today');
    expect(find.textContaining('save couldn’t be confirmed'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('review-meal-name')))
            .controller!
            .text,
        'Reviewed oats');
    await tap(tester, 'Log meal for today');
    expect(repo.ids.length, 2);
    expect(repo.ids.toSet().length, 1);
    expect((await repo.getUserMeals('member')).length, 1);
  });
  testWidgets('Unknown macros require confirmation and cancel writes nothing',
      (tester) async {
    ai.response = fullPlan
        .split('\n')
        .map((l) => l.split('|').take(4).join('|'))
        .join('\n');
    await pumpPlanner(tester);
    await generate(tester);
    await review(tester);
    await tap(tester, 'Log meal for today');
    expect(find.text('Enter grams, 0 or more.'), findsNWidgets(2));
    expect(repo.ids, isEmpty);
    await tester.enterText(
        find.byKey(const ValueKey('review-Carbs (g)')), '60');
    await tester.enterText(find.byKey(const ValueKey('review-Fat (g)')), '10');
    await tap(tester, 'Cancel');
    expect(await repo.getUserMeals('member'), isEmpty);
    expect(find.text('Logged today'), findsNothing);
  });
  testWidgets(
      'Plan survives tab switching and edited preferences do not relabel it',
      (tester) async {
    await pumpPlanner(tester);
    await generate(tester);
    await tester.tap(find.widgetWithText(Tab, 'Tracker'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Planner'));
    await tester.pumpAndSettle();
    expect(find.text('Oats'), findsOneWidget);
    await tap(tester, 'Meal preferences');
    await tap(tester, 'Lose Weight');
    await tap(tester, 'Maintain');
    expect(find.text('Lose Weight · No preference · requested 2000 kcal'),
        findsOneWidget);
    expect(await repo.getUserMeals('member'), isEmpty);
  });
  testWidgets(
      'A changed account cannot receive the earlier generation response',
      (tester) async {
    ai.pending = Completer<String>();
    await pumpPlanner(tester);
    final button = find.widgetWithText(FilledButton, 'Generate meal plan');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    final auth = BlocProvider.of<AuthCubit>(
        tester.element(find.byType(MealPlannerPage)));
    await auth.logout();
    ai.pending!.complete(fullPlan);
    await tester.pumpAndSettle();
    expect(find.text('Oats'), findsNothing);
    expect(await repo.getUserMeals('member'), isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Leaving during generation does not update a disposed widget',
      (tester) async {
    ai.pending = Completer<String>();
    await pumpPlanner(tester);
    final button = find.widgetWithText(FilledButton, 'Generate meal plan');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    ai.pending!.complete(fullPlan);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 640), const Size(800, 400)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'Planner and review reflow at $size, 200% text, $brightness and keyboard',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await pumpPlanner(tester, scale: 2, brightness: brightness);
        await generate(tester);
        expect(tester.takeException(), isNull);
        await review(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pumpAndSettle();
        await tap(tester, 'Log meal for today');
        expect(tester.takeException(), isNull);
        expect((await repo.getUserMeals('member')).length, 1);
      });
    }
  }
}
