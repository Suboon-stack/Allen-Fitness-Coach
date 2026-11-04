import 'dart:async';
import 'dart:convert';

import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/pages/home_page.dart';
import 'package:allen/fitness/pages/workout_page.dart';
import 'package:allen/fitness/pages/meal_planner_page.dart';
import 'package:allen/fitness/pages/progress_page.dart';
import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/fake_auth_repo.dart';

class _Ai extends AiService {
  _Ai({this.pending});
  final Completer<String>? pending;
  @override
  Future<String> getDailyQuote() async =>
      pending == null ? 'One step at a time.' : await pending!.future;
}

class _Workouts extends WorkoutRepository {
  _Workouts({this.fail = false, this.pending, this.count = 0});
  bool fail;
  final Completer<int>? pending;
  final int count;
  @override
  Future<int> getWorkoutCount(String userId) async {
    if (fail) throw StateError('Unavailable');
    if (pending != null) return await pending!.future;
    return count;
  }

  @override
  Future<int> getCurrentStreak(String userId) async => 0;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(WidgetTester tester,
      {WorkoutRepository? workouts,
      AiService? ai,
      Brightness brightness = Brightness.light,
      double scale = 1}) async {
    final cubit = AuthCubit(
        authRepo: FakeAuthRepo()
          ..user = AppUser(uid: 'member', email: 'member@example.com'));
    await cubit.checkAuth();
    addTearDown(cubit.close);
    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.legacyTheme,
        home: MediaQuery(
          data: MediaQueryData(
              size: tester.view.physicalSize / tester.view.devicePixelRatio,
              platformBrightness: brightness,
              textScaler: TextScaler.linear(scale)),
          child: HomePage(aiService: ai ?? _Ai(), workoutRepository: workouts),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('Loading remains visible until saved activity resolves',
      (tester) async {
    final pending = Completer<int>();
    await pumpHome(tester, workouts: _Workouts(pending: pending));
    expect(find.text('Loading your activity…'), findsOneWidget);
    pending.complete(7);
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Loading your activity…'), findsNothing);
  });

  testWidgets(
      'Activity uses repository records instead of legacy dashboard keys',
      (tester) async {
    final now = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      'workout_count': 99,
      'streak': 99,
      'weight_logs': [
        jsonEncode({'weight': 180, 'date': now})
      ],
      'workouts': jsonEncode([
        {'id': 'first', 'completed': true, 'date': now},
        {'id': 'second', 'completed': true, 'date': now},
        {'id': 'third', 'completed': false, 'date': now},
      ]),
      'weights': jsonEncode([
        {'weight': 72.4, 'date': now}
      ]),
    });
    await LocalStorageService().addWater(750);
    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('72.4 kg'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('750 ml'), findsOneWidget);
    expect(find.text('99'), findsNothing);
    expect(find.text('180.0 kg'), findsNothing);
  });

  testWidgets(
      'Core dashboard information is visible without scrolling on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await LocalStorageService().addWeight(71.2);
    await pumpHome(tester, workouts: _Workouts(count: 3));
    await tester.pumpAndSettle();
    for (final label in [
      'Ask Allen',
      'Completed workouts',
      'Latest weight',
      'Scan food'
    ]) {
      expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
    }
  });

  testWidgets('A slow Gemini quote cannot block saved activity',
      (tester) async {
    final quote = Completer<String>();
    await pumpHome(tester,
        ai: _Ai(pending: quote), workouts: _Workouts(count: 4));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Loading your activity…'), findsNothing);
    quote.complete('One step at a time.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Daily motivation'));
    await tester.tap(find.text('Daily motivation'));
    await tester.pumpAndSettle();
    expect(find.text('One step at a time.'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Narrow dashboard supports large text in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHome(tester, brightness: brightness, scale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
          Brightness.dark);
      await tester.ensureVisible(find.text('Scan food'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Failed activity offers a working retry', (tester) async {
    final workouts = _Workouts(fail: true);
    await pumpHome(tester, workouts: workouts);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Try again'));
    workouts.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Your activity couldn’t be loaded.'), findsNothing);
    expect(find.text('Not logged'), findsOneWidget);
  });

  testWidgets('Bottom shortcuts retain existing routes and refresh on return',
      (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    for (final entry in {
      'Workouts': WorkoutPage,
      'Nutrition': MealPlannerPage,
      'Progress': ProgressPage
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget);
      final destinationTheme =
          Theme.of(tester.element(find.byType(entry.value)));
      // The reviewed screen applies its scope inside its root; inspect its
      // Scaffold. Unreviewed destinations continue using the legacy route theme.
      final scaffold = find
          .descendant(
              of: find.byType(entry.value), matching: find.byType(Scaffold))
          .first;
      final routeTheme = Theme.of(tester.element(scaffold));
      expect(
          routeTheme.colorScheme.surface,
          entry.value == WorkoutPage || entry.value == MealPlannerPage
              ? AppColors.surface
              : destinationTheme.colorScheme.surface);
      if (entry.value != WorkoutPage && entry.value != MealPlannerPage) {
        expect(routeTheme.colorScheme.surface,
            AppTheme.legacyTheme.colorScheme.surface);
      }
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Ask Allen'), findsOneWidget);
    }
    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();
    await LocalStorageService().addWeight(71.2);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('71.2 kg'), findsOneWidget);
  });

  testWidgets('Drawer retains every existing feature and account action',
      (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    for (final label in [
      'Home',
      'Workouts',
      'Meal planner',
      'Calorie scanner',
      'Progress',
      'AI coach',
      'Profile',
      'Settings',
      'About',
      'Sign out'
    ]) {
      await tester.scrollUntilVisible(
          find.descendant(of: find.byType(Drawer), matching: find.text(label)),
          120,
          scrollable: find.descendant(
              of: find.byType(Drawer), matching: find.byType(Scrollable)));
      expect(find.text(label), findsWidgets);
    }
    expect(tester.takeException(), isNull);
  });
}
