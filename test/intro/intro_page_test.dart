import 'package:allen/intro/intro_page.dart';
import 'package:allen/intro/widgets/intro_motion_graphic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpIntro(WidgetTester tester, Size size,
      {double scale = 1,
      bool reduceMotion = false,
      EdgeInsets insets = EdgeInsets.zero,
      VoidCallback? onContinue,
      VoidCallback? onSignIn}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          size: size,
          padding: insets,
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
          accessibleNavigation: reduceMotion),
      child: IntroPage(onContinue: onContinue ?? () {}, onSignIn: onSignIn),
    )));
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(412, 915),
    const Size(412, 1100),
    const Size(800, 400)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Welcome keeps actions visible at $size and ${scale}x text',
          (tester) async {
        await pumpIntro(tester, size, scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Get started').hitTestable(), findsOneWidget);
        expect(find.text('Sign in').hitTestable(), findsOneWidget);
        expect(find.byType(IntroMotionGraphic), findsOneWidget);
        // Long copy may scroll at large text sizes; the fixed footer stays usable.
        await tester.ensureVisible(find.text('Fitness, on your terms.'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Get started').hitTestable(), findsOneWidget);
      });
    }
  }

  testWidgets('Welcome preserves the separate registration and sign-in actions',
      (tester) async {
    var starts = 0;
    var signs = 0;
    await pumpIntro(tester, const Size(390, 844),
        onContinue: () => starts++, onSignIn: () => signs++);
    await tester.tap(find.text('Get started'));
    await tester.tap(find.text('Sign in'));
    expect(starts, 1);
    expect(signs, 1);
  });

  testWidgets('The existing sign-in fallback still uses onContinue',
      (tester) async {
    var starts = 0;
    await pumpIntro(tester, const Size(390, 844), onContinue: () => starts++);
    await tester.tap(find.text('Sign in'));
    expect(starts, 1);
  });

  testWidgets(
      'Actions respect Android safe areas and the ribbon stays non-interactive',
      (tester) async {
    await pumpIntro(tester, const Size(390, 844),
        insets: const EdgeInsets.only(top: 32, bottom: 34));
    expect(tester.getRect(find.text('Allen')).top, greaterThanOrEqualTo(32));
    expect(tester.getRect(find.text('Sign in')).bottom,
        lessThanOrEqualTo(844 - 34));
    final graphic = find.byType(IntroMotionGraphic);
    expect(find.descendant(of: graphic, matching: find.byType(IgnorePointer)),
        findsOneWidget);
    expect(
        find.descendant(of: graphic, matching: find.byType(ExcludeSemantics)),
        findsOneWidget);
  });

  testWidgets(
      'Reduced-motion mode has no repeating animation or scheduled frames',
      (tester) async {
    await pumpIntro(tester, const Size(390, 844), reduceMotion: true);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
