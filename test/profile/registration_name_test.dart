import 'dart:async';
import 'package:allen/features/auth/data/firebase_auth_repo.dart';
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class TestUser extends Fake implements User {
  TestUser(this.uid);
  @override
  final String uid;
  @override
  String? get email => '$uid@example.com';
  @override
  String? displayName;
  String? submitted;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<void> updateDisplayName(String? value) async {
    submitted = value;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('private-error');
    displayName = value;
  }
}

class TestCredential extends Fake implements UserCredential {
  TestCredential(this.user);
  @override
  final User? user;
}

class TestFirebase extends Fake implements FirebaseAuth {
  TestFirebase(this.created) : currentUser = created;
  final TestUser created;
  @override
  User? currentUser;
  @override
  Future<UserCredential> createUserWithEmailAndPassword(
          {required String email, required String password}) async =>
      TestCredential(created);
}

void main() {
  test('Registration trims and persists Firebase display name', () async {
    final user = TestUser('a');
    final auth = TestFirebase(user);
    final result = await FirebaseAuthRepo(firebaseAuth: auth)
        .registerWithEmailPassword('  Alex  ', 'a@example.com', 'password');
    expect(user.submitted, 'Alex');
    expect(result!.displayName, 'Alex');
    expect(result.uid, 'a');
  });
  test(
      'Supplementary name failure does not turn successful registration into failure',
      () async {
    final user = TestUser('a')..fail = true;
    final auth = TestFirebase(user);
    final result = await FirebaseAuthRepo(firebaseAuth: auth)
        .registerWithEmailPassword('Alex', 'a@example.com', 'password');
    expect(result!.uid, 'a');
    expect(result.displayName, isNull);
  });
  test('Account change during name update returns the actual current identity',
      () async {
    final user = TestUser('a')..pending = Completer<void>();
    final auth = TestFirebase(user);
    final result = FirebaseAuthRepo(firebaseAuth: auth)
        .registerWithEmailPassword('Alex', 'a@example.com', 'password');
    await Future<void>.delayed(Duration.zero);
    auth.currentUser = TestUser('b');
    user.pending!.complete();
    expect((await result)!.uid, 'b');
    expect(auth.currentUser!.displayName, isNull);
  });
  test(
      'Older AppUser JSON remains supported and name survives new serialization',
      () {
    expect(AppUser.fromJson({'uid': 'a', 'email': 'a@example.com'}).displayName,
        isNull);
    final user = AppUser(uid: 'a', email: 'a@example.com', displayName: 'Alex');
    expect(AppUser.fromJson(user.toJson()).displayName, 'Alex');
  });
}
