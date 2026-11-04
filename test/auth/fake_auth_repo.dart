import 'dart:async';
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/domain/repo/auth_repo.dart';

class FakeAuthRepo implements AuthRepo {
  AppUser? user;
  Object? readError;
  Object? actionError;
  Completer<AppUser?>? pendingLogin;
  Completer<String>? pendingReset;
  bool keepSessionOnLogout = false;
  bool failAfterSignOut = false;
  String? submittedEmail;
  String? submittedPassword;
  String? submittedName;
  int loginCalls = 0;
  int resetCalls = 0;

  @override
  Future<AppUser?> getCurrentUser() async {
    if (readError != null) throw readError!;
    return user;
  }

  @override
  Future<AppUser?> loginWithEmailPassword(String email, String password) async {
    loginCalls++;
    submittedEmail = email;
    submittedPassword = password;
    if (actionError != null) throw actionError!;
    if (pendingLogin != null) user = await pendingLogin!.future;
    return user;
  }

  @override
  Future<AppUser?> registerWithEmailPassword(
      String name, String email, String password) {
    submittedName = name;
    return loginWithEmailPassword(email, password);
  }

  @override
  Future<void> logout() async {
    if (failAfterSignOut) {
      user = null;
      throw StateError('Transport failed after sign out');
    }
    if (actionError != null) throw actionError!;
    if (!keepSessionOnLogout) user = null;
  }

  @override
  Future<void> deleteAccount() => logout();
  @override
  Future<String> sendPasswordResetEmail(String email) async {
    resetCalls++;
    submittedEmail = email;
    if (actionError != null) throw actionError!;
    return pendingReset == null
        ? 'Reset your password in Email Inbox'
        : await pendingReset!.future;
  }
}
