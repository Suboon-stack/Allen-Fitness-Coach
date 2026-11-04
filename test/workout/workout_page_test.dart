import 'dart:async';
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/workout_model.dart';
import 'package:allen/fitness/pages/workout_page.dart';
import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:allen/fitness/services/workout_plan_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/fake_auth_repo.dart';
import 'workout_repository_test.dart' show sampleWorkout;

const _valid =
    'Push Ups | 3 x 12 | Chest | Rest 60 seconds\nBench Press | 4 x 8 | Chest';

class _Ai extends AiService {
  int calls = 0;
  String response = _valid;
  Object? failure;
  Completer<String>? pending;
  String? focus;
  String? level;
  String? time;
  @override
  Future<String> generateWorkout(
      {required String muscleGroup,
      required String difficulty,
      required String duration}) async {
    calls++;
    focus = muscleGroup;
    level = difficulty;
    time = duration;
    if (failure != null) throw failure!;
    return pending == null ? response : await pending!.future;
  }
}

class _Repo extends WorkoutRepository {
  int saveCalls = 0;
  int completeCalls = 0;
  int readCalls = 0;
  bool failRead = false;
  bool failSave = false;
  bool failComplete = false;
  bool failAfterWriteOnce = false;
  Completer<void>? saveGate;
  Completer<void>? completeGate;
  final completionIds = <String>[];
  @override
  Future<List<Workout>> getUserWorkouts(String userId, {int limit = 50}) async {
    readCalls++;
    if (failRead) {
      throw const WorkoutStorageException(
          'Saved workouts couldn’t be read. Please retry.');
    }
    return super.getUserWorkouts(userId, limit: limit);
  }

  @override
  Future<String> createWorkout(Workout workout) async {
    saveCalls++;
    if (failSave) throw StateError('Write failed');
    if (saveGate != null) await saveGate!.future;
    final id = await super.createWorkout(workout);
    if (failAfterWriteOnce) {
      failAfterWriteOnce = false;
      throw StateError('Write confirmation failed');
    }
    return id;
  }

  @override
  Future<void> markWorkoutComplete(String workoutId, bool completed) async {
    completeCalls++;
    completionIds.add(workoutId);
    if (failComplete) throw StateError('Completion failed');
    if (completeGate != null) await completeGate!.future;
    await super.markWorkoutComplete(workoutId, completed);
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
      {Brightness brightness = Brightness.light, double scale = 1}) async {
    final auth = AuthCubit(
        authRepo: FakeAuthRepo()
          ..user = AppUser(uid: 'member', email: 'member@example.com'));
    await auth.checkAuth();
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  platformBrightness: brightness),
              child: child!),
          home: WorkoutPage(aiService: ai, repository: repo),
        )));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) => tap(tester, 'Generate workout');
  Future<void> saved(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, 'Saved'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Generation is single-flight, exposes loading, and renders only supplied exercise details',
      (tester) async {
    ai.pending = Completer<String>();
    await pumpPlanner(tester);
    final button = find.text('Generate workout');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(ai.calls, 1);
    expect(find.text('Building your workout…'), findsOneWidget);
    ai.pending!.complete(_valid);
    await tester.pumpAndSettle();
    expect(find.text('Chest workout'), findsOneWidget);
    expect(find.text('Intermediate · 45 min · 2 exercises'), findsOneWidget);
    expect(find.text('3 sets × 12 reps · Chest'), findsOneWidget);
    expect(find.text('Rest 60 seconds'), findsOneWidget);
    expect(repo.saveCalls, 0);
  });

  testWidgets(
      'Malformed responses preserve preferences and provide an explicit retry',
      (tester) async {
    ai.response = 'Push Ups | not-sets | Chest';
    await pumpPlanner(tester);
    await generate(tester);
    expect(
        find.textContaining('unsupported set or rep format'), findsOneWidget);
    expect(find.text('Save workout'), findsNothing);
    expect(await LocalStorageService().getWorkouts(), isEmpty);
    ai.response = _valid;
    await tap(tester, 'Try generating again');
    expect(find.text('Chest workout'), findsOneWidget);
    expect(ai.calls, 2);
  });

  testWidgets(
      'A Gemini failure shows a helpful message without a predefined plan',
      (tester) async {
    ai.failure = const WorkoutGenerationException(
        'Allen is unavailable. Please try again.');
    await pumpPlanner(tester);
    await generate(tester);
    expect(
        find.text('Allen is unavailable. Please try again.'), findsOneWidget);
    expect(find.text('Save workout'), findsNothing);
    expect(repo.saveCalls, 0);
  });

  testWidgets('Save and completion use one UUID and ignore duplicate actions',
      (tester) async {
    await pumpPlanner(tester);
    await generate(tester);
    repo.saveGate = Completer<void>();
    await tester.tap(find.text('Save workout'));
    await tester.tap(find.text('Save workout'));
    await tester.pump();
    expect(repo.saveCalls, 1);
    expect(find.text('Saving…'), findsOneWidget);
    repo.saveGate!.complete();
    await tester.pumpAndSettle();
    final id =
        (await LocalStorageService().getWorkouts()).single['id'] as String;
    repo.completeGate = Completer<void>();
    await tester.tap(find.text('Complete workout'));
    await tester.tap(find.text('Complete workout'));
    await tester.pump();
    expect(repo.completeCalls, 1);
    repo.completeGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.completionIds, [id]);
    expect((await LocalStorageService().getWorkouts()).single['completed'],
        isTrue);
    expect(repo.saveCalls, 1);
  });

  testWidgets(
      'Save & complete retries partial failure without creating a second workout',
      (tester) async {
    repo.failComplete = true;
    await pumpPlanner(tester);
    await generate(tester);
    await tap(tester, 'Save & complete');
    expect(repo.saveCalls, 1);
    expect(repo.completeCalls, 1);
    expect(find.textContaining('saved, but completion failed'), findsOneWidget);
    expect((await LocalStorageService().getWorkouts()), hasLength(1));
    repo.failComplete = false;
    await tap(tester, 'Complete workout');
    expect(repo.saveCalls, 1);
    expect(repo.completeCalls, 2);
    expect(repo.completionIds.toSet(), hasLength(1));
    expect((await LocalStorageService().getWorkouts()).single['completed'],
        isTrue);
  });

  testWidgets('A retry after an uncertain write reuses the same draft UUID',
      (tester) async {
    repo.failAfterWriteOnce = true;
    await pumpPlanner(tester);
    await generate(tester);
    await tap(tester, 'Save workout');
    expect(find.textContaining('couldn’t be confirmed'), findsOneWidget);
    expect(await LocalStorageService().getWorkouts(), hasLength(1));
    await tap(tester, 'Save workout');
    expect(await LocalStorageService().getWorkouts(), hasLength(1));
    expect(repo.saveCalls, 2);
  });

  testWidgets(
      'Save failure remains retryable without losing the generated plan',
      (tester) async {
    repo.failSave = true;
    await pumpPlanner(tester);
    await generate(tester);
    await tap(tester, 'Save workout');
    expect(find.text('Chest workout'), findsOneWidget);
    expect(await LocalStorageService().getWorkouts(), isEmpty);
    repo.failSave = false;
    await tap(tester, 'Save workout');
    expect(await LocalStorageService().getWorkouts(), hasLength(1));
  });

  testWidgets('Saved session completion refreshes its status and filters',
      (tester) async {
    await repo.createWorkout(sampleWorkout('saved-id'));
    await pumpPlanner(tester);
    expect(repo.readCalls, 1);
    await saved(tester);
    await tap(tester, 'Chest workout');
    await tap(tester, 'Mark complete');
    expect(repo.completionIds, ['saved-id']);
    expect(find.text('Mark complete'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ready'));
    await tester.pumpAndSettle();
    expect(find.text('No ready workouts'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Chest workout'), findsOneWidget);
    expect(repo.readCalls, 2);
  });

  testWidgets('History failures are distinct from empty states and can recover',
      (tester) async {
    repo.failRead = true;
    await pumpPlanner(tester);
    await saved(tester);
    expect(find.textContaining('couldn’t be read'), findsOneWidget);
    expect(find.text('No saved workouts yet'), findsNothing);
    repo.failRead = false;
    await tap(tester, 'Try again');
    expect(find.text('No saved workouts yet'), findsOneWidget);
  });

  testWidgets(
      'Delete requires confirmation and refreshes history only after success',
      (tester) async {
    await repo.createWorkout(sampleWorkout('to-delete'));
    await pumpPlanner(tester);
    await saved(tester);
    await tap(tester, 'Chest workout');
    await tap(tester, 'Delete');
    await tap(tester, 'Cancel');
    expect(await LocalStorageService().getWorkouts(), hasLength(1));
    await tap(tester, 'Delete');
    await tap(tester, 'Delete workout');
    expect(await LocalStorageService().getWorkouts(), isEmpty);
    expect(find.text('No saved workouts yet'), findsOneWidget);
  });

  testWidgets(
      'Editing preferences after generation does not relabel the saved plan',
      (tester) async {
    await pumpPlanner(tester);
    await generate(tester);
    await tap(tester, 'Workout preferences');
    await tester.ensureVisible(find.byKey(const Key('workout-focus')));
    await tester.tap(find.byKey(const Key('workout-focus')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legs').last);
    await tester.pumpAndSettle();
    await tap(tester, '20 min');
    await tap(tester, 'Save workout');
    final workout =
        (await WorkoutRepository().getUserWorkouts('member')).single;
    expect(workout.muscleGroup, 'Chest');
    expect(workout.durationMinutes, 45);
    expect(ai.focus, 'Chest');
    expect(ai.time, '45 min');
  });

  testWidgets('Leaving during generation does not update a disposed widget',
      (tester) async {
    ai.pending = Completer<String>();
    await pumpPlanner(tester);
    await tester.tap(find.text('Generate workout'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    ai.pending!.complete(_valid);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(await LocalStorageService().getWorkouts(), isEmpty);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'Planner and saved details support a 320px phone and 200% text in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPlanner(tester, brightness: brightness, scale: 2);
      expect(tester.takeException(), isNull);
      await generate(tester);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Save workout');
      await saved(tester);
      await tap(tester, 'Chest workout');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Mark complete'));
      expect(tester.takeException(), isNull);
    });
  }
}
