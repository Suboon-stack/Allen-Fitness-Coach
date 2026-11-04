import 'dart:async';
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/pages/password_reset_page.dart';
import 'package:allen/intro/intro_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_auth_repo.dart';

void main() {
  late FakeAuthRepo repo;
  late AuthCubit cubit;
  setUp(() {
    repo = FakeAuthRepo();
    cubit = AuthCubit(authRepo: repo);
  });
  tearDown(() => cubit.close());

  Future<void> pumpGate(WidgetTester tester,
      {double scale = 1, Brightness brightness = Brightness.light}) async {
    await cubit.checkAuth();
    await tester.pumpWidget(BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  platformBrightness: brightness),
              child: child!),
          home: IntroGate(
              authenticatedBuilder: (context) => Scaffold(
                    body: Center(
                        child: FilledButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => Scaffold(
                                        body: Center(
                                            child: FilledButton(
                                                onPressed: cubit.logout,
                                                child:
                                                    const Text('Sign out')))))),
                            child: const Text('Open account'))),
                  )),
        )));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump();
  }

  String value(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  testWidgets('Sign-in draft survives loading, rejection, and form switching',
      (tester) async {
    await pumpGate(tester);
    await tap(tester, 'Sign in');
    await enter(tester, 'login-email', 'member@example.com');
    await enter(tester, 'login-password', 'a-password');
    repo.pendingLogin = Completer<AppUser?>();
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Signing in…'), findsOneWidget);
    expect(value(tester, 'login-email'), 'member@example.com');
    expect(value(tester, 'login-password'), 'a-password');
    expect(repo.loginCalls, 1);
    repo.pendingLogin!
        .completeError(FirebaseAuthException(code: 'invalid-credential'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Check your email and password.'), findsOneWidget);
    expect(value(tester, 'login-password'), 'a-password');
    await tap(tester, 'Create an account');
    await tap(tester, 'Sign in');
    expect(value(tester, 'login-email'), 'member@example.com');
    expect(value(tester, 'login-password'), 'a-password');
  });

  testWidgets('Registration validates fields and retains draft while switching',
      (tester) async {
    await pumpGate(tester);
    await tap(tester, 'Get started');
    await tap(tester, 'Create account');
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(repo.loginCalls, 0);
    await enter(tester, 'register-name', 'Alex');
    await enter(tester, 'register-email', 'not-an-email');
    await enter(tester, 'register-password', '123');
    await enter(tester, 'register-confirm', 'different');
    await tap(tester, 'Create account');
    expect(find.text('Use an email like you@example.com.'), findsOneWidget);
    expect(find.text('Use at least 6 characters.'), findsOneWidget);
    expect(find.text('Your passwords don’t match.'), findsOneWidget);
    await tap(tester, 'Sign in');
    await tap(tester, 'Create an account');
    expect(value(tester, 'register-name'), 'Alex');
    expect(value(tester, 'register-password'), '123');
  });

  testWidgets(
      'Registration preserves values during request and passes original credentials',
      (tester) async {
    await pumpGate(tester);
    await tap(tester, 'Get started');
    await enter(tester, 'register-name', ' Alex ');
    await enter(tester, 'register-email', 'member@example.com');
    await enter(tester, 'register-password', 'my-password');
    await enter(tester, 'register-confirm', 'my-password');
    repo.pendingLogin = Completer<AppUser?>();
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Creating your account…'), findsOneWidget);
    expect(value(tester, 'register-name'), ' Alex ');
    expect(repo.submittedName, 'Alex');
    expect(repo.submittedPassword, 'my-password');
    repo.pendingLogin!
        .complete(AppUser(uid: 'member', email: 'member@example.com'));
    await tester.pumpAndSettle();
    expect(find.text('Open account'), findsOneWidget);
  });

  testWidgets('Password visibility control preserves input', (tester) async {
    await pumpGate(tester);
    await tap(tester, 'Sign in');
    await enter(tester, 'login-password', 'private-password');
    final password = find.byKey(const Key('login-password'));
    expect(
        tester
            .widget<EditableText>(find.descendant(
                of: password, matching: find.byType(EditableText)))
            .obscureText,
        isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
        tester
            .widget<EditableText>(find.descendant(
                of: password, matching: find.byType(EditableText)))
            .obscureText,
        isFalse);
    expect(value(tester, 'login-password'), 'private-password');
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(
        tester
            .widget<EditableText>(find.descendant(
                of: password, matching: find.byType(EditableText)))
            .obscureText,
        isTrue);
  });

  testWidgets(
      'Reset has pending, error, and success states without clearing sign-in draft',
      (tester) async {
    await pumpGate(tester);
    await tap(tester, 'Sign in');
    await enter(tester, 'login-email', 'member@example.com');
    await enter(tester, 'login-password', 'my-password');
    await tap(tester, 'Forgot password?');
    expect(value(tester, 'reset-email'), 'member@example.com');
    repo.actionError = FirebaseAuthException(code: 'network-request-failed');
    await tap(tester, 'Send reset link');
    expect(find.textContaining('internet connection'), findsOneWidget);
    repo.actionError = null;
    repo.pendingReset = Completer<String>();
    await tester.ensureVisible(find.text('Send reset link'));
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Sending your link…'), findsOneWidget);
    repo.pendingReset!.complete(AuthCubit.passwordResetSuccess);
    await tester.pumpAndSettle();
    expect(find.text('Check your\ninbox.'), findsOneWidget);
    await tap(tester, 'Back to sign in');
    expect(value(tester, 'login-email'), 'member@example.com');
    expect(value(tester, 'login-password'), 'my-password');
  });

  testWidgets(
      'Reset can be closed during request without a disposed-state error',
      (tester) async {
    await pumpGate(tester);
    await tap(tester, 'Sign in');
    await enter(tester, 'login-email', 'member@example.com');
    await tap(tester, 'Forgot password?');
    repo.pendingReset = Completer<String>();
    await tester.ensureVisible(find.text('Send reset link'));
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(PasswordResetPage))).pop();
    await tester.pumpAndSettle();
    repo.pendingReset!.complete(AuthCubit.passwordResetSuccess);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Restored session skips intro and sign out dismisses account routes',
      (tester) async {
    repo.user = AppUser(uid: 'member', email: 'member@example.com');
    await pumpGate(tester);
    expect(find.text('Get started'), findsNothing);
    await tap(tester, 'Open account');
    await tap(tester, 'Sign out');
    expect(find.text('Good to have\nyou back.'), findsOneWidget);
    expect(find.text('Open account'), findsNothing);
  });

  testWidgets(
      'Failed restoration exposes retry and recovers the actual session',
      (tester) async {
    repo.readError = StateError('Unavailable');
    await pumpGate(tester);
    expect(find.text('Let’s reconnect.'), findsOneWidget);
    repo.readError = null;
    repo.user = AppUser(uid: 'member', email: 'member@example.com');
    await tap(tester, 'Try again');
    expect(find.text('Open account'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 1200.0]) {
      testWidgets(
          'Auth layouts at width $width, 200% text, $brightness and keyboard',
          (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await pumpGate(tester, scale: 2, brightness: brightness);
        expect(tester.takeException(), isNull);
        await tap(tester, 'Get started');
        expect(tester.takeException(), isNull);
        await enter(tester, 'register-email', 'member@example.com');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Create account'));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tap(tester, 'Sign in');
        await tap(tester, 'Forgot password?');
        expect(tester.takeException(), isNull);
        await enter(tester, 'reset-email', 'bad-address');
        await tap(tester, 'Send reset link');
        expect(repo.resetCalls, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
