import 'dart:math' as math;
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/workout_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) =>
    (math.max(a.computeLuminance(), b.computeLuminance()) + .05) /
    (math.min(a.computeLuminance(), b.computeLuminance()) + .05);

void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(
          theme: AppTheme.legacyTheme,
          home: AppThemeScope(child: Scaffold(body: child))));
  Color? renderedColor(WidgetTester tester, String label) => tester
      .widget<RichText>(find.descendant(
          of: find.text(label), matching: find.byType(RichText)))
      .text
      .style
      ?.color;

  test('Normal text, selected labels, disabled labels, and errors meet 4.5:1',
      () {
    for (final pair in <(Color, Color)>[
      (AppColors.text, AppColors.background),
      (AppColors.textSecondary, AppColors.surface),
      (AppColors.text, AppColors.primary),
      (AppColors.secondary, AppColors.surface),
      (AppColors.disabledText, AppColors.disabledSurface),
      (AppColors.error, AppColors.surface),
      (AppColors.onError, AppColors.errorSurface),
      (AppColors.text, AppColors.selectedSurface),
    ]) {
      expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    }
  });

  test(
      'Field boundaries and focus/loading indicators have at least 3:1 contrast',
      () {
    expect(contrast(AppColors.outline, AppColors.surface),
        greaterThanOrEqualTo(3));
    expect(contrast(AppColors.secondary, AppColors.surface),
        greaterThanOrEqualTo(3));
    expect(contrast(AppColors.secondary, AppColors.surfaceHigh),
        greaterThanOrEqualTo(3));
  });

  for (final brightness in Brightness.values) {
    testWidgets('Reviewed scopes keep Midnight under system $brightness',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(platformBrightness: brightness),
        child:
            const AppThemeScope(child: Scaffold(body: Text('Reviewed screen'))),
      )));
      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF101827));
      expect(theme.colorScheme.surface, const Color(0xFF1C2940));
      expect(theme.colorScheme.primary, const Color(0xFF315CF5));
      expect(theme.colorScheme.secondary, const Color(0xFFAFC4FF));
      expect(theme.colorScheme.onSurface, const Color(0xFFF2F5FA));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFB2BED0));
    });
  }

  testWidgets(
      'Selected duration/filter chip text stays readable after selection changes',
      (tester) async {
    var selected = 30;
    await pump(
        tester,
        StatefulBuilder(
            builder: (context, setState) => Wrap(children: [
                  for (final minutes in [30, 45])
                    ChoiceChip(
                        label: Text('$minutes min'),
                        showCheckmark: false,
                        selected: selected == minutes,
                        onSelected: (_) => setState(() => selected = minutes)),
                  const ChoiceChip(label: Text('Unavailable'), selected: false),
                  const ChoiceChip(
                      label: Text('Selected while loading'), selected: true),
                ])));
    expect(renderedColor(tester, '30 min'), AppColors.text);
    expect(renderedColor(tester, '45 min'), AppColors.textSecondary);
    expect(renderedColor(tester, 'Unavailable'), AppColors.disabledText);
    expect(renderedColor(tester, 'Selected while loading'), AppColors.text);
    expect(tester.getSize(find.byType(ChoiceChip).first).height,
        greaterThanOrEqualTo(48));
    expect(contrast(renderedColor(tester, '30 min')!, AppColors.primary),
        greaterThanOrEqualTo(4.5));
    await tester.tap(find.text('45 min'));
    await tester.pumpAndSettle();
    expect(renderedColor(tester, '45 min'), AppColors.text);
    expect(renderedColor(tester, '30 min'), AppColors.textSecondary);
  });

  testWidgets('Disabled save buttons remain readable and ignore taps',
      (tester) async {
    await pump(
        tester, const FilledButton(onPressed: null, child: Text('Saving…')));
    final color = renderedColor(tester, 'Saving…');
    expect(color, AppColors.disabledText);
    expect(
        contrast(color!, AppColors.disabledSurface), greaterThanOrEqualTo(4.5));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });

  testWidgets('Inline workout errors inherit readable semantic colors',
      (tester) async {
    await pump(tester,
        WorkoutFeedback('Save could not be confirmed.', onRetry: () {}));
    expect(renderedColor(tester, 'Save could not be confirmed.'),
        AppColors.onError);
    expect(renderedColor(tester, 'Try again'), AppColors.secondary);
    expect(contrast(AppColors.secondary, AppColors.errorSurface),
        greaterThanOrEqualTo(4.5));
  });

  testWidgets(
      'Active navigation labels use light text instead of low-contrast blue',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AppThemeScope(
            child: Scaffold(
      bottomNavigationBar: NavigationBar(
          selectedIndex: 1,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.fitness_center), label: 'Workouts'),
          ]),
    ))));
    await tester.pumpAndSettle();
    expect(renderedColor(tester, 'Workouts'), AppColors.text);
    expect(renderedColor(tester, 'Home'), AppColors.textSecondary);
  });

  testWidgets('Dialogs opened from reviewed screens retain Midnight',
      (tester) async {
    await pump(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        const AlertDialog(title: Text('Delete workout?'))),
                child: const Text('Open dialog'))));
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(AlertDialog)));
    expect(theme.dialogTheme.backgroundColor, AppColors.surface);
    expect(theme.colorScheme.onSurface, AppColors.text);
  });

  testWidgets(
      'Untouched routes retain the legacy theme and back restores Midnight',
      (tester) async {
    await pump(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Untouched route')))),
                child: const Text('Open route'))));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();
    expect(
        Theme.of(tester.element(find.text('Untouched route')))
            .colorScheme
            .surface,
        AppTheme.legacyTheme.colorScheme.surface);
    Navigator.of(tester.element(find.text('Untouched route'))).pop();
    await tester.pumpAndSettle();
    expect(
        Theme.of(tester.element(find.text('Open route'))).colorScheme.surface,
        AppColors.surface);
  });
}
