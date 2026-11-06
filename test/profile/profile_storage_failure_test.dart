import 'dart:async';
import 'dart:convert';
import 'package:allen/features/auth/data/user_repository.dart';
import 'package:allen/fitness/models/profile_overview_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_repository_test.dart' show profile;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  late Map<String, Object> disk;
  String? owner;
  bool reject = false, throwWrite = false;
  Completer<bool>? ack;
  setUp(() {
    SharedPreferences.resetStatic();
    disk = {};
    owner = 'a';
    reject = false;
    throwWrite = false;
    ack = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') return Map<String, Object>.from(disk);
      if (call.method == 'setString') {
        if (throwWrite) throw PlatformException(code: 'private-details');
        if (reject) return false;
        final args = call.arguments as Map;
        disk[args['key']] = args['value'];
        return ack != null ? await ack!.future : true;
      }
      throw StateError('Unexpected preferences call');
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
  });
  UserRepository repo() => UserRepository(authenticatedUser: () => owner);
  for (final throwing in [true, false]) {
    test(
        'Native profile failure cannot be mistaken for persisted data ($throwing)',
        () async {
      reject = !throwing;
      throwWrite = throwing;
      await expectLater(
          repo().createUserProfile(profile('a')), throwsA(anything));
      expect(disk, isEmpty);
      expect(await repo().getUserProfile('a'), isNull);
      reject = false;
      throwWrite = false;
      await repo().createUserProfile(profile('a'));
      expect((await repo().getUserProfile('a'))!.name, 'A');
    });
  }
  test('Account switch invalidates queued writes and read acknowledgments',
      () async {
    ack = Completer<bool>();
    final repository = repo();
    final first = repository.updateUserProfile(profile('a', name: 'First'));
    final firstResult =
        expectLater(first, throwsA(isA<ProfileStorageException>()));
    while (disk.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final queued = repository.updateUserProfile(profile('a', name: 'Queued'));
    final queuedResult =
        expectLater(queued, throwsA(isA<ProfileStorageException>()));
    final reading = repository.getUserProfile('a');
    final readResult =
        expectLater(reading, throwsA(isA<ProfileStorageException>()));
    owner = 'b';
    ack!.complete(true);
    await Future.wait([firstResult, queuedResult, readResult]);
    expect(disk.keys, ['flutter.user_profile_a']);
    expect(jsonDecode(disk.values.single as String)['name'], 'First');
    expect(await repository.getUserProfile('b'), isNull);
  });
}
