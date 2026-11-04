import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/tracker_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpRing(WidgetTester tester,
      {double value = 500,
      double? goal,
      double scale = 1,
      bool reduce = false}) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 640),
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduce),
            child: AppThemeScope(
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: SizedBox(
                            width: 280,
                            child: TrackerProgress(
                                value: value,
                                unit: 'kcal',
                                centerIcon: const NutritionAppleIcon(),
                                semanticName: 'Calories',
                                goal: goal))))))));
    await tester.pumpAndSettle();
  }

  for (final goal in [null, 0.0, -1.0, double.nan, double.infinity]) {
    testWidgets('No invented percentage for missing or invalid goal $goal',
        (tester) async {
      await pumpRing(tester, goal: goal);
      expect(find.text('No goal configured.'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(
          tester
              .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator))
              .value,
          0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Shows actual over-goal percentage while clamping only the arc',
      (tester) async {
    await pumpRing(tester, value: 2500, goal: 2000);
    expect(find.text('125% of goal'), findsOneWidget);
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        1);
    final semantics = tester.ensureSemantics();

    expect(
        find.bySemanticsLabel(
            RegExp('Calories, 2,500 kcal logged today.*125% of goal')),
        findsOneWidget);
    semantics.dispose();
  });
  testWidgets('Large text reflows and reduced-motion removes interpolation',
      (tester) async {
    await pumpRing(tester, goal: 2000, scale: 2, reduce: true);
    expect(tester.takeException(), isNull);
    expect(
        tester
            .widget<TweenAnimationBuilder<double>>(
                find.byType(TweenAnimationBuilder<double>))
            .duration,
        Duration.zero);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('500'), findsOneWidget);
  });
  testWidgets(
      'Invalid recorded value shows unavailable rather than a percentage',
      (tester) async {
    await pumpRing(tester, value: double.nan, goal: 2000);
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });
}
