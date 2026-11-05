import 'dart:async';
import 'dart:io';
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/food_estimate.dart';
import 'package:allen/fitness/pages/calorie_scanner_page.dart';
import 'package:allen/fitness/pages/food_camera_page.dart';
import 'package:allen/fitness/pages/meal_planner_page.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/services/scanner_camera.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/chat_widgets.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/fake_auth_repo.dart';
import 'food_scanner_controller_test.dart' show ScannerAi, estimate;

class FakeScannerCamera implements ScannerCamera {
  bool initialized = false, closed = false;
  int captures = 0, switches = 0;
  Object? failure;
  Completer<void>? opening;
  Completer<File>? taking;
  bool multiple = true;
  @override
  bool get ready => initialized && !closed;
  @override
  bool get canSwitch => multiple;
  @override
  double get aspectRatio => 4 / 3;
  @override
  Widget preview() =>
      const ColoredBox(key: Key('native-preview'), color: AppColors.surface);
  @override
  Future<void> initialize() async {
    if (opening != null) await opening!.future;
    if (failure != null) throw failure!;
    initialized = true;
  }

  @override
  Future<File> capture() async {
    captures++;
    if (taking != null) return await taking!.future;
    return File('web/favicon.png');
  }

  @override
  Future<void> switchLens() async {
    switches++;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  late ScannerAi ai;
  late FakeAuthRepo authRepo;
  late AuthCubit auth;
  late MealRepository meals;
  late FakeScannerCamera camera;
  late Future<File?> Function() picker;
  late ScannerCamera Function() makeCamera;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ai = ScannerAi();
    meals = MealRepository();
    camera = FakeScannerCamera();
    makeCamera = () => camera;
    authRepo = FakeAuthRepo()
      ..user = AppUser(uid: 'member', email: 'member@example.com');
    auth = AuthCubit(authRepo: authRepo);
    await auth.checkAuth();
    picker = () async => File('web/favicon.png');
  });
  tearDown(() async => auth.close());
  Future<void> pump(WidgetTester tester,
      {double scale = 1, bool route = false}) async {
    final screen = CalorieScannerPage(
        aiService: ai,
        repository: meals,
        pickGallery: () => picker(),
        cameraFactory: () => makeCamera());
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
                                MaterialPageRoute<void>(
                                    builder: (_) => screen)),
                            child: const Text('Open scanner'))))
                : screen)));
    await tester.pumpAndSettle();
    if (route) {
      await tester.tap(find.text('Open scanner'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester) async =>
      tap(tester, find.byKey(const Key('scanner-gallery')));
  Future<void> generate(WidgetTester tester) async {
    await select(tester);
    await tester.ensureVisible(find.byKey(const Key('scanner-analyze')));
    await tester.tap(find.byKey(const Key('scanner-analyze')));
    await tester.pump();
    ai.calls.last.complete(estimate());
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Reference dashboard uses Midnight and original sparkle, real actions, no fake history',
      (tester) async {
    await pump(tester);
    expect(find.text('Allen'), findsOneWidget);
    expect(find.byType(AllenSparkle), findsOneWidget);
    expect(find.text('Scan Your Food'), findsOneWidget);
    expect(find.text('Recent Scans'), findsNothing);
    expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        AppColors.background);
    expect(ai.calls, isEmpty);
    await select(tester);
    expect(find.text('Ready to analyze?'), findsOneWidget);
    expect(ai.calls, isEmpty);
    expect(await meals.getUserMeals('member'), isEmpty);
  });
  testWidgets(
      'Gallery cancellation and errors preserve dashboard; duplicate picker blocked',
      (tester) async {
    final pending = Completer<File?>();
    var picks = 0;
    picker = () {
      picks++;
      return pending.future;
    };
    await pump(tester);
    await tester.tap(find.byKey(const Key('scanner-gallery')));
    await tester.pump();
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('scanner-gallery')))
            .onPressed,
        isNull);
    expect(picks, 1);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Scan Your Food'), findsOneWidget);
    picker = () async => throw StateError('private-file-path');
    await select(tester);
    expect(
        find.textContaining('The photo couldn’t be opened.'), findsOneWidget);
    expect(find.textContaining('private-file-path'), findsNothing);
  });
  testWidgets(
      'Loading disables duplicate analyze; safe errors offer retry and retain photo',
      (tester) async {
    await pump(tester);
    await select(tester);
    await tester.ensureVisible(find.byKey(const Key('scanner-analyze')));
    await tester.tap(find.byKey(const Key('scanner-analyze')));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('scanner-analyze')))
            .onPressed,
        isNull);
    expect(ai.calls.length, 1);
    ai.calls.single
        .completeError(const FoodScanException(FoodScanFailure.network));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.text('Retry analysis'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scanner-analyze')));
    await tester.pump();
    ai.calls.last.complete(estimate());
    await tester.pumpAndSettle();
    expect(find.text('AI Estimate'), findsOneWidget);
    expect(find.text('Identified items'), findsNothing);
  });
  testWidgets(
      'Edit validates values; Apply does not save; confirmed Save updates Nutrition once',
      (tester) async {
    await pump(tester);
    await generate(tester);
    await tap(tester, find.byKey(const Key('scan-edit')));
    await tester.enterText(
        find.byKey(const Key('scan-edit-name')), 'Reviewed rice');
    await tester.enterText(find.byKey(const Key('scan-edit-macro-0')), '-1');
    await tap(tester, find.byKey(const Key('scan-apply-edit')));
    expect(find.text('Enter whole calories, 0 or more.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('scan-edit-macro-0')), '520');
    await tap(tester, find.byKey(const Key('scan-apply-edit')));
    expect(await meals.getUserMeals('member'), isEmpty);
    expect(find.text('Reviewed rice'), findsOneWidget);
    await tap(tester, find.byKey(const Key('scan-save')));
    expect((await meals.getUserMeals('member')).single.calories, 520);
    expect(find.byKey(const Key('scan-save')), findsNothing);
    await tap(tester, find.text('View Nutrition'));
    expect(find.byType(MealPlannerPage), findsOneWidget);
    expect(find.text('Reviewed rice'), findsOneWidget);
    expect(find.text('AI Estimate · reviewed'), findsOneWidget);
    expect(
        (await MealRepository()
            .getDailyNutrition('member', DateTime.now()))['calories'],
        520);
  });
  testWidgets(
      'Android Back cancels pending analysis; later response cannot repopulate cleared screen',
      (tester) async {
    await pump(tester, route: true);
    await select(tester);
    await tester.ensureVisible(find.byKey(const Key('scanner-analyze')));
    await tester.tap(find.byKey(const Key('scanner-analyze')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Scan Your Food'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    ai.calls.single.complete(estimate());
    await tester.pumpAndSettle();
    expect(find.text('Open scanner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Account changes discard pending picker, analysis and visible estimate',
      (tester) async {
    await pump(tester);
    await select(tester);
    await tester.ensureVisible(find.byKey(const Key('scanner-analyze')));
    await tester.tap(find.byKey(const Key('scanner-analyze')));
    await tester.pump();
    await auth.logout();
    await tester.pumpAndSettle();
    ai.calls.single.complete(estimate());
    await tester.pumpAndSettle();
    expect(find.text('AI Estimate'), findsNothing);
    expect(find.textContaining('Sign in to analyze'), findsOneWidget);
    expect(await meals.getUserMeals('member'), isEmpty);
  });
  testWidgets(
      'Camera route uses actual preview boundary; capture returns review without upload; switch supported',
      (tester) async {
    await pump(tester);
    await tap(tester, find.byKey(const Key('scanner-camera')));
    expect(find.byType(FoodCameraPage), findsOneWidget);
    expect(find.byKey(const Key('native-preview')), findsOneWidget);
    await tap(tester, find.byTooltip('Switch camera'));
    expect(camera.switches, 1);
    await tap(tester, find.byKey(const Key('scanner-shutter')));
    expect(camera.captures, 1);
    expect(camera.closed, isTrue);
    expect(find.text('Ready to analyze?'), findsOneWidget);
    expect(ai.calls, isEmpty);
  });
  testWidgets('Camera denial is sanitized and gallery remains available',
      (tester) async {
    camera.failure =
        CameraException('CameraAccessDenied', 'private camera details');
    await pump(tester);
    await tap(tester, find.byKey(const Key('scanner-camera')));
    expect(find.textContaining('Allow camera access'), findsOneWidget);
    expect(find.textContaining('private camera'), findsNothing);
    await tap(tester, find.byTooltip('Choose from gallery'));
    expect(find.text('Ready to analyze?'), findsOneWidget);
    expect(ai.calls, isEmpty);
  });
  testWidgets(
      'Back while camera initialization is pending safely releases without setState after dispose',
      (tester) async {
    camera.opening = Completer<void>();
    await pump(tester);
    await tester.tap(find.byKey(const Key('scanner-camera')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    camera.opening!.complete();
    await tester.pumpAndSettle();
    expect(camera.closed, isTrue);
    expect(find.text('Scan Your Food'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Native picker reply after account switch is discarded',
      (tester) async {
    final pending = Completer<File?>();
    picker = () => pending.future;
    await pump(tester);
    await tester.tap(find.byKey(const Key('scanner-gallery')));
    await tester.pump();
    await auth.logout();
    await tester.pumpAndSettle();
    pending.complete(File('web/favicon.png'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to analyze?'), findsNothing);
    expect(ai.calls, isEmpty);
  });
  testWidgets(
      'Camera background/resume releases old session before opening a new session',
      (tester) async {
    final sessions = <FakeScannerCamera>[];
    makeCamera = () {
      final next = FakeScannerCamera();
      sessions.add(next);
      return next;
    };
    await pump(tester);
    await tap(tester, find.byKey(const Key('scanner-camera')));
    expect(sessions.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(sessions.length, 2);
    expect(sessions.first.closed, isTrue);
    expect(sessions.last.ready, isTrue);
    expect(find.byKey(const Key('native-preview')), findsOneWidget);
  });
  testWidgets(
      'Pending capture prevents duplicate shutter and ignores late photo after Back',
      (tester) async {
    camera.taking = Completer<File>();
    await pump(tester);
    await tap(tester, find.byKey(const Key('scanner-camera')));
    await tester.tap(find.byKey(const Key('scanner-shutter')));
    await tester.pump();
    expect(camera.captures, 1);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('scanner-shutter')))
            .onPressed,
        isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    camera.taking!.complete(File('web/favicon.png'));
    await tester.pumpAndSettle();
    expect(find.text('Scan Your Food'), findsOneWidget);
    expect(ai.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Gallery cancellation recovers camera; single-camera devices omit switch',
      (tester) async {
    final sessions = <FakeScannerCamera>[];
    makeCamera = () {
      final next = FakeScannerCamera()..multiple = false;
      sessions.add(next);
      return next;
    };
    picker = () async => null;
    await pump(tester);
    await tap(tester, find.byKey(const Key('scanner-camera')));
    expect(find.byTooltip('Switch camera'), findsNothing);
    await tap(tester, find.byTooltip('Choose from gallery'));
    expect(sessions.length, 2);
    expect(sessions.first.closed, isTrue);
    expect(find.byType(FoodCameraPage), findsOneWidget);
    expect(ai.calls, isEmpty);
  });
  testWidgets(
      'Result editing stays scrollable above keyboard and Android bottom inset',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPadding);
    await pump(tester);
    await generate(tester);
    await tap(tester, find.byKey(const Key('scan-edit')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.view.padding = const FakeViewPadding(bottom: 24);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('scan-edit-portion')), 'One reviewed bowl');
    await tap(tester, find.byKey(const Key('scan-apply-edit')));
    expect(find.textContaining('One reviewed bowl'), findsOneWidget);
    expect(await meals.getUserMeals('member'), isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(800, 400)
  ]) {
    testWidgets(
        'Dashboard, camera, result and edit fit $size at 200% text scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, scale: 2);
      expect(tester.takeException(), isNull);
      await tap(tester, find.byKey(const Key('scanner-camera')));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await generate(tester);
      expect(tester.takeException(), isNull);
      await tap(tester, find.byKey(const Key('scan-edit')));
      expect(tester.takeException(), isNull);
      await tester.enterText(
          find.byKey(const Key('scan-edit-name')), 'Edited food');
      await tap(tester, find.byKey(const Key('scan-apply-edit')));
      expect(tester.takeException(), isNull);
    });
  }
}
