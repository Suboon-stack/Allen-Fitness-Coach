import 'dart:async';
import 'dart:convert';
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/meal_model.dart';
import 'package:allen/fitness/pages/meal_planner_page.dart';
import 'package:allen/fitness/pages/home_page.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/meal_entry_sheet.dart';
import 'package:allen/fitness/widgets/tracker_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/fake_auth_repo.dart';
import 'meal_repository_test.dart' show sampleMeal;

class _Meals extends MealRepository {
  int reads = 0;
  bool failRead = false, failSave = false, failAfterWrite = false;
  Completer<void>? pendingSave;
  final ids = <String>[];
  @override
  Future<List<Meal>> getMealsByDate(String userId, DateTime date) async {
    reads++;
    if (failRead) {
      throw const MealStorageException('Meals couldn’t be read. Please retry.');
    }
    return super.getMealsByDate(userId, date);
  }

  @override
  Future<String> createMeal(Meal meal) async {
    ids.add(meal.id);
    if (pendingSave != null) await pendingSave!.future;
    if (failSave) throw StateError('private native detail');
    final id = await super.createMeal(meal);
    if (failAfterWrite) {
      failAfterWrite = false;
      throw StateError('confirmation lost');
    }
    return id;
  }
}

class _Water extends ProgressRepository {
  int writes = 0;
  bool failRead = false, failWrite = false;
  Completer<void>? pending;
  @override
  Future<int> getTodayWaterIntake(String userId) async {
    if (failRead) throw StateError('private native detail');
    return super.getTodayWaterIntake(userId);
  }

  @override
  Future<String> addWaterIntake(String userId, int amount) async {
    writes++;
    if (pending != null) await pending!.future;
    if (failWrite) throw StateError('unconfirmed write');
    return super.addWaterIntake(userId, amount);
  }
}

class _Ai extends AiService {
  @override
  Future<String> getDailyQuote() async => 'Keep going.';
}

void main() {
  late _Meals meals;
  late _Water water;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    meals = _Meals();
    water = _Water();
  });
  Future<void> pump(WidgetTester tester,
      {double scale = 1,
      Brightness brightness = Brightness.dark,
      bool reduce = false,
      bool home = false}) async {
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
                    platformBrightness: brightness,
                    disableAnimations: reduce),
                child: child!),
            home: home
                ? HomePage(aiService: _Ai())
                : MealPlannerPage(
                    aiService: _Ai(),
                    repository: meals,
                    progressRepository: water))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final f = find.text(text).last;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> waterTab(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, 'Water'));
    await tester.pumpAndSettle();
  }

  Future<void> fillMeal(WidgetTester tester, {String name = 'My lunch'}) async {
    await tester.enterText(find.byKey(const Key('entry-meal-name')), name);
    for (final e in [
      ('Calories (kcal)', '450'),
      ('Protein (g)', '30.5'),
      ('Carbohydrates (g)', '50'),
      ('Fat (g)', '12')
    ]) {
      await tester.enterText(find.byKey(ValueKey('entry-${e.$1}')), e.$2);
    }
  }

  TrackerProgress calorieRing(WidgetTester tester) =>
      tester.widget<TrackerProgress>(find.byKey(const Key('calorie-progress')));
  TrackerProgress waterRing(WidgetTester tester) =>
      tester.widget<TrackerProgress>(find.byKey(const Key('water-progress')));

  testWidgets(
      'Empty Tracker shows confirmed zero without an invented calorie target',
      (tester) async {
    await pump(tester);
    expect(calorieRing(tester).value, 0);
    expect(calorieRing(tester).goal, isNull);
    expect(find.text('No calorie goal configured.'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('No meals recorded today.'), findsOneWidget);
    expect(find.text('Add Meal'), findsOneWidget);
  });
  testWidgets(
      'Ring, macros and meal list use the same records and actual owned profile goals',
      (tester) async {
    await meals.createMeal(sampleMeal('a'));
    await meals.createMeal(sampleMeal('b', calories: 200));
    await meals.createMeal(sampleMeal('foreign', user: 'another'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'user_profile',
        jsonEncode({
          'id': 'member',
          'targetCalories': 1200,
          'targetProtein': 100,
          'targetCarbs': 200,
          'targetFat': 50
        }));
    await pump(tester);
    expect(calorieRing(tester).value, 600);
    expect(calorieRing(tester).goal, 1200);
    expect(find.text('50% of goal'), findsOneWidget);
    expect(find.text('40 g'), findsOneWidget);
    expect(find.text('120 g'), findsOneWidget);
    expect(find.text('20 g'), findsOneWidget);
    expect(find.text('Oats'), findsNWidgets(2));
    final reads = meals.reads;
    await tester.pump();
    expect(meals.reads, reads);
  });
  testWidgets('Foreign or invalid goals do not become percentages',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'user_profile', jsonEncode({'id': 'another', 'targetCalories': 2000}));
    await pump(tester);
    expect(calorieRing(tester).goal, isNull);
    expect(find.textContaining('%'), findsNothing);
  });
  testWidgets('Read errors have retry and do not masquerade as zero totals',
      (tester) async {
    meals.failRead = true;
    await pump(tester);
    expect(find.byKey(const Key('calorie-progress')), findsNothing);
    expect(find.textContaining('Meals couldn’t be read'), findsOneWidget);
    meals.failRead = false;
    await tap(tester, 'Try again');
    expect(calorieRing(tester).value, 0);
  });
  testWidgets(
      'Meal sheet validates all fields, saves once and refreshes totals',
      (tester) async {
    await pump(tester);
    await tap(tester, 'Add Meal');
    expect(
        Theme.of(tester.element(find.byType(MealEntrySheet)))
            .colorScheme
            .surface,
        AppColors.surface);
    await tap(tester, 'Save meal');
    expect(find.text('Enter a meal name.'), findsOneWidget);
    expect(meals.ids, isEmpty);
    await fillMeal(tester);
    await tester.enterText(find.byKey(const ValueKey('entry-Fat (g)')), 'NaN');
    await tap(tester, 'Save meal');
    expect(find.text('Enter grams, 0 or more.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('entry-Fat (g)')), '12');
    meals.pendingSave = Completer<void>();
    final button = find.widgetWithText(FilledButton, 'Save meal');
    await tester.ensureVisible(button);
    final action = tester.widget<FilledButton>(button).onPressed!;
    action();
    action();
    await tester.pump();
    expect(meals.ids.length, 1);
    expect(find.text('Saving meal…'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('entry-meal-name')))
            .controller!
            .text,
        'My lunch');
    meals.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(calorieRing(tester).value, 450);
    expect(find.text('My lunch'), findsOneWidget);
    expect((await meals.getUserMeals('member')).single.protein, 30.5);
  });
  testWidgets(
      'Failed save retains fields; edited retry updates the same confirmed UUID',
      (tester) async {
    await pump(tester);
    await tap(tester, 'Add Meal');
    await fillMeal(tester);
    meals.failAfterWrite = true;
    await tap(tester, 'Save meal');
    expect(find.textContaining('save couldn’t be confirmed'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('entry-meal-name')))
            .controller!
            .text,
        'My lunch');
    await tester.enterText(
        find.byKey(const Key('entry-meal-name')), 'Corrected lunch');
    await tap(tester, 'Save meal');
    expect(meals.ids.length, 2);
    expect(meals.ids.toSet().length, 1);
    expect((await meals.getUserMeals('member')).single.name, 'Corrected lunch');
    expect(find.text('Corrected lunch'), findsOneWidget);
  });
  testWidgets('Cancel discards an unsubmitted form without creating a meal',
      (tester) async {
    await pump(tester);
    await tap(tester, 'Add Meal');
    await fillMeal(tester);
    await tap(tester, 'Cancel');
    expect(await meals.getUserMeals('member'), isEmpty);
  });
  testWidgets(
      'Water uses labeled app default and serializes repeat taps without blocking later entries',
      (tester) async {
    await pump(tester);
    await waterTab(tester);
    expect(waterRing(tester).goal, 2000);
    expect(find.text('App default goal · 2,000 ml'), findsOneWidget);
    water.pending = Completer<void>();
    final button = find.widgetWithText(FilledButton, '+250 ml');
    await tester.ensureVisible(button);
    final action = tester.widget<FilledButton>(button).onPressed!;
    action();
    action();
    await tester.pump();
    expect(water.writes, 1);
    expect(find.text('Saving water…'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '+100 ml'))
            .onPressed,
        isNull);
    water.pending!.complete();
    await tester.pumpAndSettle();
    expect(waterRing(tester).value, 250);
    water.pending = null;
    await tap(tester, '+250 ml');
    expect(water.writes, 2);
    expect(waterRing(tester).value, 500);
  });
  testWidgets(
      'Uncertain water write requires refreshing before another addition',
      (tester) async {
    await pump(tester);
    await waterTab(tester);
    water.failWrite = true;
    await tap(tester, '+100 ml');
    expect(find.textContaining('Refresh your total before adding again'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '+100 ml'))
            .onPressed,
        isNull);
    water.failWrite = false;
    await tap(tester, 'Try again');
    expect(waterRing(tester).value, 0);
    await tap(tester, '+100 ml');
    expect(waterRing(tester).value, 100);
  });
  testWidgets('Returning Home reads the same water total as Nutrition',
      (tester) async {
    await pump(tester, home: true);
    await tap(tester, 'Nutrition');
    await waterTab(tester);
    await tap(tester, '+250 ml');
    expect(waterRing(tester).value, 250);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('250 ml'), findsOneWidget);
  });
  for (final size in [const Size(320, 640), const Size(800, 400)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'Both trackers and meal sheet reflow at $size, 200% text, $brightness',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await pump(tester, scale: 2, brightness: brightness, reduce: true);
        expect(tester.takeException(), isNull);
        await tap(tester, 'Add Meal');
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pumpAndSettle();
        await fillMeal(tester);
        await tap(tester, 'Save meal');
        expect(calorieRing(tester).value, 450);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await waterTab(tester);
        await tap(tester, '+500 ml');
        expect(waterRing(tester).value, 500);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
