import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:allen/fitness/models/nutrition_tracker_data.dart';
import 'package:allen/fitness/models/progress_model.dart';
import 'package:allen/fitness/models/progress_tracking_data.dart';
import 'package:allen/fitness/pages/progress_page.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/progress_timeline.dart';
import 'package:allen/fitness/widgets/weight_entry_sheet.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/fake_auth_repo.dart';
import 'progress_data_test.dart' show weight;

class ControlledProgress extends ProgressRepository {
  ControlledProgress({required super.authenticatedUser});
  final pending = <Completer<ProgressSnapshot>>[];
  final owners = <String>[];
  bool fail = false;
  @override
  Future<ProgressSnapshot> loadTracking(String owner) async {
    owners.add(owner);
    if (fail) throw StateError('private-provider-detail');
    final next = Completer<ProgressSnapshot>();
    pending.add(next);
    return next.future;
  }
}

class BlockingProgress extends ProgressRepository {
  BlockingProgress({required super.authenticatedUser});
  Completer<void>? gate;
  int saves = 0;
  @override
  Future<String> addWeightEntry(WeightEntry entry) async {
    saves++;
    if (gate != null) await gate!.future;
    return super.addWeightEntry(entry);
  }
}

void main() {
  late AuthCubit auth;
  late FakeAuthRepo authRepo;
  late ProgressRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    authRepo = FakeAuthRepo()
      ..user = AppUser(uid: 'member', email: 'member@example.com');
    auth = AuthCubit(authRepo: authRepo);
    await auth.checkAuth();
    repository = ProgressRepository(
        authenticatedUser: () =>
            auth.state is AuthLoading ? null : auth.currentUser?.uid);
  });
  tearDown(() async => auth.close());
  Future<void> pump(WidgetTester tester,
      {double scale = 1, bool route = false}) async {
    final page = ProgressPage(repository: repository);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.legacyTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: route
                ? Builder(
                    builder: (context) => Scaffold(
                        body: TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => page)),
                            child: const Text('Open progress'))))
                : page)));
    await tester.pump();
    if (route) {
      await tester.tap(find.text('Open progress'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> populate() async {
    final now = DateTime.now();
    await repository.addWeightEntry(
        weight('earlier', 70, now.subtract(const Duration(days: 20))));
    await repository.addWeightEntry(
        weight('recent', 71, now.subtract(const Duration(days: 2))));
    await LocalStorageService().saveWorkouts([
      {
        'id': 'complete',
        'userId': 'member',
        'name': 'Upper body',
        'completed': true,
        'date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'durationMinutes': 45
      }
    ]);
    await LocalStorageService().saveMeals([
      {
        'id': 'meal',
        'userId': 'member',
        'name': 'Rice bowl',
        'mealTime': 'Lunch',
        'calories': 400,
        'protein': 20,
        'carbs': 60,
        'fat': 10,
        'date': now.toIso8601String(),
        'createdAt': now.toIso8601String()
      }
    ]);
    await LocalStorageService().saveUserProfile(
        {'id': 'member', 'targetCalories': 2000, 'targetProtein': 100});
  }

  testWidgets(
      'Empty reference layout uses Midnight, real empty states, no fabricated rings or milestones',
      (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Your Journey'), findsOneWidget);
    expect(find.text('Your journey, at your pace'), findsOneWidget);
    expect(find.text('Weight Progress'), findsOneWidget);
    expect(find.text('Key Progress'), findsOneWidget);
    expect(find.text('Activity Timeline'), findsOneWidget);
    expect(find.text('No weight measurements in this period.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        find.textContaining('Account ownership not supported'), findsOneWidget);
    expect(find.textContaining('Reached 5-Day'), findsNothing);
    expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        AppColors.background);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
  });
  testWidgets(
      'Populated chart uses dated x values, filters, accurate metrics and genuine timeline',
      (tester) async {
    await populate();
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('+1.0 kg across 2 check-ins'), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots.length, 2);
    expect(
        chart.data.lineBarsData.single.spots.last.x -
            chart.data.lineBarsData.single.spots.first.x,
        closeTo(18, 0.01));
    expect(chart.data.lineBarsData.single.isCurved, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    await tap(tester, find.byKey(const Key('progress-period-7D')));
    expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .length,
        1);
    expect(find.textContaining('One check-in so far.'), findsOneWidget);
    final timeline =
        tester.widget<ProgressTimeline>(find.byType(ProgressTimeline));
    expect(timeline.events.any((e) => e.title == 'Upper body'), isTrue);
    expect(timeline.events.any((e) => e.detail == 'Completed · 45 min plan'),
        isTrue);
    expect(timeline.events.any((e) => e.detail.contains('burned')), isFalse);
  });
  testWidgets(
      'Accessible point navigation and touch select dates/values without editing or saving',
      (tester) async {
    await populate();
    await pump(tester);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const Key('progress-selected-weight')))
            .data,
        startsWith('71.0 kg'));
    await tap(tester, find.byTooltip('Previous measurement'));
    expect(
        tester
            .widget<Text>(find.byKey(const Key('progress-selected-weight')))
            .data,
        startsWith('70.0 kg'));
    await tap(tester, find.byTooltip('Next measurement'));
    expect(
        tester
            .widget<Text>(find.byKey(const Key('progress-selected-weight')))
            .data,
        startsWith('71.0 kg'));
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    chart.data.lineTouchData.touchCallback!(
        FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
        LineTouchResponse([
          TouchLineBarSpot(chart.data.lineBarsData.single, 0,
              chart.data.lineBarsData.single.spots.first, 0)
        ]));
    await tester.pump();
    expect(
        tester
            .widget<Text>(find.byKey(const Key('progress-selected-weight')))
            .data,
        startsWith('70.0 kg'));
    expect((await repository.getWeightEntries('member')).length, 2);
  });
  testWidgets(
      'Log form validates, saves authenticated owner and updates the chart',
      (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('progress-log-weight')));
    await tap(tester, find.byKey(const Key('weight-save')));
    expect(find.textContaining('Enter a weight above 0'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('weight-value')), '72.5');
    await tester.enterText(
        find.byKey(const Key('weight-notes')), 'Morning check-in');
    await tap(tester, find.byKey(const Key('weight-save')));
    expect(find.byType(WeightEntrySheet), findsNothing);
    final value = (await repository.getWeightEntries('member')).single;
    expect(value.id, isNotEmpty);
    expect(value.userId, 'member');
    expect(value.notes, 'Morning check-in');
    expect(find.textContaining('72.5 kg'), findsWidgets);
  });
  testWidgets(
      'Edit keeps record ID and ownership; legacy records remain unchanged',
      (tester) async {
    await populate();
    final legacy = {
      'weight': 90,
      'date': DateTime.now().toIso8601String(),
      'keep': true
    };
    final raw = await LocalStorageService().getWeights();
    raw.add(legacy);
    await LocalStorageService().saveWeights(raw);
    await pump(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Edit measurement'));
    await tester.enterText(find.byKey(const Key('weight-value')), '73');
    await tap(tester, find.byKey(const Key('weight-save')));
    final values = await repository.getWeightEntries('member');
    expect(values.singleWhere((e) => e.id == 'recent').weight, 73);
    expect(values.length, 2);
    expect((await LocalStorageService().getWeights()).last, legacy);
  });
  testWidgets(
      'Global error is safe and retry recovers without inventing zero values',
      (tester) async {
    final controlled =
        ControlledProgress(authenticatedUser: () => auth.currentUser?.uid)
          ..fail = true;
    repository = controlled;
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-error')), findsOneWidget);
    expect(find.textContaining('private-provider'), findsNothing);
    controlled.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    controlled.pending.single.complete(ProgressSnapshot(
        weights: [], workouts: [], meals: [], goals: const NutritionGoals()));
    await tester.pumpAndSettle();
    expect(find.text('Your Journey'), findsOneWidget);
  });
  testWidgets(
      'Partial read failure leaves other real history usable and offers retry',
      (tester) async {
    await populate();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weights', 'invalid');
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Some progress data couldn’t load: weights'),
        findsOneWidget);
    expect(find.text('Weight history is unavailable. Retry to load it.'),
        findsOneWidget);
    expect(find.text('Upper body'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
  testWidgets(
      'Logout while editing discards the old form and cannot save old owner data',
      (tester) async {
    await populate();
    await pump(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Edit measurement'));
    await tester.enterText(find.byKey(const Key('weight-value')), '99');
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.byType(WeightEntrySheet), findsNothing);
    expect(find.textContaining('Sign in to view'), findsOneWidget);
    expect(
        (await repository.getWeightEntries('member'))
            .singleWhere((e) => e.id == 'recent')
            .weight,
        71);
  });
  testWidgets(
      'Account switch invalidates earlier pending read and clears prior user content',
      (tester) async {
    final controlled =
        ControlledProgress(authenticatedUser: () => auth.currentUser?.uid);
    repository = controlled;
    await pump(tester);
    authRepo.user = AppUser(uid: 'other', email: 'other@example.com');
    await auth.checkAuth();
    await tester.pump();
    expect(controlled.owners, ['member', 'other']);
    controlled.pending.first.complete(
        ProgressSnapshot(weights: [weight('private', 88, DateTime.now())]));
    await tester.pump();
    controlled.pending.last.complete(ProgressSnapshot(
        weights: [], workouts: [], meals: [], goals: const NutritionGoals()));
    await tester.pumpAndSettle();
    expect(find.textContaining('88.0 kg'), findsNothing);
  });
  testWidgets(
      'Leaving during read ignores completion without setState after disposal',
      (tester) async {
    final controlled =
        ControlledProgress(authenticatedUser: () => auth.currentUser?.uid);
    repository = controlled;
    await pump(tester, route: true);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    controlled.pending.single.complete(ProgressSnapshot(weights: []));
    await tester.pumpAndSettle();
    expect(find.text('Open progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Pending weight save disables duplicate submission and persists once',
      (tester) async {
    final blocked =
        BlockingProgress(authenticatedUser: () => auth.currentUser?.uid);
    repository = blocked;
    await pump(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('progress-log-weight')));
    await tester.enterText(find.byKey(const Key('weight-value')), '74');
    blocked.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('weight-save')));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('weight-save')))
            .onPressed,
        isNull);
    expect(blocked.saves, 1);
    blocked.gate!.complete();
    await tester.pumpAndSettle();
    expect((await repository.getWeightEntries('member')).length, 1);
  });
  testWidgets(
      'Account change during delete confirmation dismisses both routes and preserves the record',
      (tester) async {
    await populate();
    await pump(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Edit measurement'));
    await tap(tester, find.byKey(const Key('weight-delete')));
    expect(find.text('Delete this measurement?'), findsOneWidget);
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(WeightEntrySheet), findsNothing);
    expect((await repository.getWeightEntries('member')).length, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Details provides an accessible dated list and opens the selected owned record',
      (tester) async {
    await populate();
    await pump(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.text('See details'));
    await tap(
        tester,
        find.descendant(
            of: find.byType(ListTile), matching: find.text('70.0 kg')));
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('weight-value')))
            .controller!
            .text,
        '70.0');
    await tester.enterText(find.byKey(const Key('weight-value')), '70.5');
    await tap(tester, find.byKey(const Key('weight-save')));
    expect(
        (await repository.getWeightEntries('member'))
            .singleWhere((e) => e.id == 'earlier')
            .weight,
        70.5);
  });
  testWidgets('Weight form remains keyboard-safe above Android system insets',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPadding);
    await pump(tester);
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('progress-log-weight')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.view.padding = const FakeViewPadding(bottom: 24);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weight-value')), '74.2');
    await tap(tester, find.byKey(const Key('weight-save')));
    expect(tester.takeException(), isNull);
    expect((await repository.getWeightEntries('member')).single.weight, 74.2);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 400)
  ]) {
    testWidgets('Reference layout and edit form fit $size at 200% text scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await populate();
      await pump(tester, scale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, find.byKey(const Key('progress-log-weight')));
      await tester.enterText(find.byKey(const Key('weight-value')), '74.2');
      await tap(tester, find.byKey(const Key('weight-save')));
      expect(tester.takeException(), isNull);
    });
  }
}
