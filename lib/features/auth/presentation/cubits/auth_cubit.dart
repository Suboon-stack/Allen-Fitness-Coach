import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/domain/repo/auth_repo.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo authRepo;
  AppUser? _currentUser;

  AuthCubit({required this.authRepo}) : super(AuthInitial());

  AppUser? get currentUser => _currentUser;
  static const passwordResetSuccess = 'Reset your password in Email Inbox';

  Future<void> checkAuth() async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    try {
      _currentUser = await authRepo.getCurrentUser();
      _emitSession();
    } catch (_) {
      emit(AuthError('We couldn’t check your session. Please try again.',
          sessionUnresolved: true));
    }
  }

  Future<void> login(String email, String pw) => _authenticate(
        () => authRepo.loginWithEmailPassword(email.trim(), pw),
      );

  Future<void> register(String name, String email, String pw) => _authenticate(
        () => authRepo.registerWithEmailPassword(name.trim(), email.trim(), pw),
      );

  Future<void> _authenticate(Future<AppUser?> Function() action) async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    try {
      _currentUser = await action();
      if (_currentUser == null) {
        await _recoverSession('We couldn’t sign you in. Please try again.');
      } else {
        _emitSession();
      }
    } catch (error) {
      await _recoverSession(_message(error));
    }
  }

  Future<void> logout() => _endSession(authRepo.logout);

  Future<void> deleteAccount() => _endSession(authRepo.deleteAccount);

  Future<void> _endSession(Future<void> Function() action) async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    try {
      await action();
      // Reconcile with Firebase through the existing repository contract rather
      // than assuming an account operation changed the session successfully.
      _currentUser = await authRepo.getCurrentUser();
      if (_currentUser != null) {
        emit(AuthError('Your account is still signed in. Please try again.'));
      }
      _emitSession();
    } catch (error) {
      await _recoverSession(_message(error));
    }
  }

  Future<void> _recoverSession(String message) async {
    try {
      _currentUser = await authRepo.getCurrentUser();
    } catch (_) {
      // Keep the cached identity for recovery, but do not present it as verified.
      emit(AuthError('$message We couldn’t verify your session. Try again.',
          sessionUnresolved: true));
      return;
    }
    emit(AuthError(message));
    _emitSession();
  }

  void _emitSession() {
    final user = _currentUser;
    emit(user == null ? Unauthenticated() : Authenticated(user));
  }

  Future<String> forgetPassword(String email) async {
    try {
      return await authRepo.sendPasswordResetEmail(email.trim());
    } catch (error) {
      return _message(error);
    }
  }

  String _message(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'We couldn’t sign you in with those details. Check your email and password.';
        case 'email-already-in-use':
          return 'An account already uses this email. Try signing in instead.';
        case 'weak-password':
          return 'Choose a stronger password with at least 6 characters.';
        case 'network-request-failed':
          return 'Check your internet connection, then try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a little before trying again.';
        case 'requires-recent-login':
          return 'For your security, sign out and sign in again before deleting your account.';
        case 'user-disabled':
          return 'This account is disabled. Please contact your account administrator.';
      }
    }
    return 'We couldn’t complete that request. Please try again.';
  }
}
