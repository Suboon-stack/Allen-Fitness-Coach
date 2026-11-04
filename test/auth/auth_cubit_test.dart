import 'dart:async';
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_auth_repo.dart';

void main() {
  late FakeAuthRepo repo;
  late AuthCubit cubit;
  final user = AppUser(uid: 'test-user', email: 'member@example.com');
  setUp(() {
    repo = FakeAuthRepo();
    cubit = AuthCubit(authRepo: repo);
  });
  tearDown(() => cubit.close());

  test('Restoration loading is explicitly marked as session verification', () async {
    final states = <AuthState>[];
    final subscription = cubit.stream.listen(states.add);
    await cubit.checkAuth();
    await Future<void>.delayed(Duration.zero);
    expect(states.whereType<AuthLoading>().single.verifyingSession, isTrue);
    await subscription.cancel();
  });

  test('Restores a persisted identity without requiring login', () async {
    repo.user = user;
    await cubit.checkAuth();
    expect(cubit.state, isA<Authenticated>());
    expect(cubit.currentUser, same(user));
  });
  test('Restoration failure is retryable and does not invent sign out',
      () async {
    repo.readError = StateError('Unavailable');
    await cubit.checkAuth();
    expect((cubit.state as AuthError).sessionUnresolved, isTrue);
    repo.readError = null;
    repo.user = user;
    await cubit.checkAuth();
    expect(cubit.currentUser, same(user));
    expect(cubit.state, isA<Authenticated>());
  });
  test('Successful logout clears cached identity', () async {
    repo.user = user;
    await cubit.checkAuth();
    await cubit.logout();
    expect(cubit.currentUser, isNull);
    expect(cubit.state, isA<Unauthenticated>());
  });
  test('Failed logout keeps the actual signed-in identity', () async {
    repo.user = user;
    await cubit.checkAuth();
    repo.actionError = StateError('Unavailable');
    await cubit.logout();
    expect(cubit.currentUser, same(user));
    expect(cubit.state, isA<Authenticated>());
  });
  test(
      'Deletion requiring reauthentication preserves session and explains recovery',
      () async {
    repo.user = user;
    await cubit.checkAuth();
    final states = <AuthState>[];
    final subscription = cubit.stream.listen(states.add);
    repo.actionError = FirebaseAuthException(code: 'requires-recent-login');
    await cubit.deleteAccount();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.currentUser, same(user));
    expect(states.whereType<AuthError>().single.message,
        contains('sign out and sign in again'));
    expect(cubit.state, isA<Authenticated>());
    await subscription.cancel();
  });
  test('Successful account deletion clears the session', () async {
    repo.user = user;
    await cubit.checkAuth();
    await cubit.deleteAccount();
    expect(cubit.currentUser, isNull);
    expect(cubit.state, isA<Unauthenticated>());
  });
  test('An error after Firebase signs out still resolves to signed out',
      () async {
    repo.user = user;
    await cubit.checkAuth();
    repo.failAfterSignOut = true;
    await cubit.logout();
    expect(cubit.currentUser, isNull);
    expect(cubit.state, isA<Unauthenticated>());
  });
  test('An unchanged Firebase session is not reported as signed out', () async {
    repo.user = user;
    await cubit.checkAuth();
    repo.keepSessionOnLogout = true;
    await cubit.logout();
    expect(cubit.currentUser, same(user));
    expect(cubit.state, isA<Authenticated>());
  });
  test('Indeterminate session after a failed operation requires verification',
      () async {
    repo.user = user;
    await cubit.checkAuth();
    repo.actionError = StateError('Failure');
    repo.readError = StateError('Unknown');
    await cubit.deleteAccount();
    expect((cubit.state as AuthError).sessionUnresolved, isTrue);
  });
  test('Prevents duplicate submissions and trims email but preserves password',
      () async {
    repo.pendingLogin = Completer<AppUser?>();
    final request = cubit.login('  member@example.com ', ' password ');
    await cubit.login('other@example.com', 'other');
    expect(repo.loginCalls, 1);
    expect(repo.submittedEmail, 'member@example.com');
    expect(repo.submittedPassword, ' password ');
    repo.pendingLogin!.complete(user);
    await request;
    expect(cubit.state, isA<Authenticated>());
  });
  test('Reset preserves the existing success contract and maps Firebase errors',
      () async {
    expect(await cubit.forgetPassword(' member@example.com '),
        AuthCubit.passwordResetSuccess);
    expect(repo.submittedEmail, 'member@example.com');
    repo.actionError = FirebaseAuthException(code: 'network-request-failed');
    expect(await cubit.forgetPassword('member@example.com'),
        contains('internet connection'));
  });
}
