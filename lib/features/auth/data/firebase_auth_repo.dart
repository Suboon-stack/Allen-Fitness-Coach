import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/domain/repo/auth_repo.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthRepo implements AuthRepo {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  @override
  Future<void> deleteAccount() async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    // Let FirebaseAuthException retain its code (e.g. requires-recent-login).
    await user.delete();
    await logout();
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final user = firebaseAuth.currentUser;
    if (user == null) return null;
    return AppUser(uid: user.uid, email: user.email ?? '');
  }

  @override
  Future<AppUser?> loginWithEmailPassword(String email, String password) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email, password: password);
    final user = credential.user;
    return user == null
        ? null
        : AppUser(uid: user.uid, email: user.email ?? email);
  }

  @override
  Future<void> logout() => firebaseAuth.signOut();

  @override
  Future<AppUser?> registerWithEmailPassword(
      String name, String email, String password) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = credential.user;
    // Existing name/profile persistence is deliberately deferred: no schema or
    // local account ownership changes are part of this authentication stage.
    return user == null
        ? null
        : AppUser(uid: user.uid, email: user.email ?? email);
  }

  @override
  Future<String> sendPasswordResetEmail(String email) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
    return 'Reset your password in Email Inbox';
  }
}
