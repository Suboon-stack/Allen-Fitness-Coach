import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:allen/features/auth/data/user_repository.dart';
import 'package:allen/fitness/models/user_profile_model.dart';
import 'package:allen/fitness/models/profile_overview_data.dart';
import 'package:allen/fitness/models/progress_tracking_data.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:allen/fitness/services/profile_export_service.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserProfile profile(String id,
        {String? name = 'A', int? calories = 1800, DateTime? created}) =>
    UserProfile(
        id: id,
        email: '$id@example.com',
        name: name,
        age: 30,
        height: 175,
        weight: 75,
        targetCalories: calories,
        createdAt: created ?? DateTime(2026, 1),
        updatedAt: DateTime(2026, 11));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? owner;
  late UserRepository repo;
  final local = LocalStorageService();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    owner = 'a';
    repo = UserRepository(authenticatedUser: () => owner);
  });
  test('New profile persists in UID key across repository recreation',
      () async {
    await repo.createUserProfile(profile('a'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('user_profile_a'), isNotNull);
    expect(prefs.getString('user_profile'), isNull);
    expect(
        (await UserRepository(authenticatedUser: () => owner)
                .getUserProfile('a'))
            ?.name,
        'A');
  });
  test('Different accounts retain their own names and targets', () async {
    await repo.createUserProfile(profile('a', name: 'Alpha'));
    owner = 'b';
    expect(await repo.getUserProfile('b'), isNull);
    await repo.createUserProfile(profile('b', name: 'Beta', calories: 2200));
    owner = 'a';
    expect((await repo.getUserProfile('a'))?.name, 'Alpha');
    owner = 'b';
    expect((await repo.getUserProfile('b'))?.targetCalories, 2200);
  });
  test('Reading and writing another account are rejected', () async {
    await expectLater(
        repo.getUserProfile('b'), throwsA(isA<ProfileStorageException>()));
    await expectLater(repo.createUserProfile(profile('b')),
        throwsA(isA<ProfileStorageException>()));
    owner = null;
    await expectLater(repo.createUserProfile(profile('a')),
        throwsA(isA<ProfileStorageException>()));
  });
  for (final id in [null, 'b']) {
    test('Unowned or foreign legacy profile stays byte-identical ($id)',
        () async {
      final legacy = jsonEncode({
        'if': 'unknown fields survive',
        'name': 'Legacy',
        if (id != null) 'id': id
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', legacy);
      expect(await repo.getUserProfile('a'), isNull);
      await repo.createUserProfile(profile('a'));
      expect(prefs.getString('user_profile'), legacy);
    });
  }
  test('Verified legacy profile is readable; editing writes owned copy only',
      () async {
    await local.saveUserProfile({
      'id': 'a',
      'email': 'a@example.com',
      'name': 'Old',
      'createdAt': '2020-01-01T00:00:00.000',
      'custom': 'retained'
    });
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString('user_profile');
    expect((await repo.getUserProfile('a'))?.name, 'Old');
    await repo.updateUserProfile(profile('a', name: 'New'));
    expect(prefs.getString('user_profile'), legacy);
    final data = await local.getUserProfile(userId: 'a');
    expect(data!['custom'], 'retained');
    expect(data['createdAt'], '2020-01-01T00:00:00.000');
  });
  test('Invalid owned profile cannot fall back to shared profile', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'user_profile_a', jsonEncode({'id': 'b', 'name': 'Other'}));
    await expectLater(
        repo.getUserProfile('a'), throwsA(isA<ProfileStorageException>()));
    await expectLater(repo.updateUserProfile(profile('a')), throwsA(anything));
    expect(jsonDecode(prefs.getString('user_profile_a')!)['id'], 'b');
  });
  test(
      'Editing preserves identity and creation date and can clear optional goals',
      () async {
    final original = DateTime(2025, 2);
    await repo.createUserProfile(profile('a', created: original));
    await repo.updateUserProfile(profile('a', name: null, calories: null));
    final saved = await repo.getUserProfile('a');
    expect(saved!.id, 'a');
    expect(saved.createdAt, original);
    expect(saved.name, isNull);
    expect(saved.targetCalories, isNull);
  });
  test('Rapid profile writes serialize without losing account boundaries',
      () async {
    await Future.wait([
      repo.updateUserProfile(profile('a', name: 'First')),
      repo.updateUserProfile(profile('a', name: 'Second'))
    ]);
    expect((await repo.getUserProfile('a'))?.name, 'Second');
  });
  test('Profile validation rejects invalid measurements', () async {
    final bad = UserProfile(
        id: 'a',
        email: '',
        weight: double.nan,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
    await expectLater(
        repo.createUserProfile(bad), throwsA(isA<ProfileStorageException>()));
    expect(await repo.getUserProfile('a'), isNull);
  });
  test(
      'Export is JSON-safe and contains only records with exact account ownership',
      () async {
    await repo.createUserProfile(profile('a'));
    final records = [
      {'userId': 'a', 'id': 'mine'},
      {'userId': 'b', 'id': 'other'},
      {'id': 'unowned'}
    ];
    await local.saveWorkouts(records);
    await local.saveMeals(records);
    await local.saveWeights(records);
    await local.addWater(500);
    final data = jsonDecode(jsonEncode(await repo.exportUserData('a'))) as Map;
    for (final key in ['workouts', 'meals', 'weights']) {
      expect((data[key] as List).single['id'], 'mine');
    }
    expect(data['profile']['createdAt'], isA<String>());
    expect(data.containsKey('water'), isFalse);
    expect((await local.getWeights()).length, 3);
  });
  test('Foreign legacy profile excluded from export without deletion',
      () async {
    await local.saveUserProfile({'id': 'b', 'name': 'private'});
    expect((await repo.exportUserData('a'))['profile'], isNull);
    expect((await local.getUserProfile())!['name'], 'private');
  });
  test('Progress target reader uses per-account profile before legacy',
      () async {
    await local.saveUserProfile({'id': 'b', 'targetCalories': 999});
    await repo.createUserProfile(profile('a', calories: 1800));
    final progress = ProgressRepository(authenticatedUser: () => owner);
    expect((await progress.loadTracking('a')).goals?.calories, 1800);
    expect((await progress.loadTracking('b')).goals?.calories, 999);
    expect((await progress.loadTracking('unowned')).goals?.calories, isNull);
  });
  test(
      'Workout streak uses calendar dates, deduplicates and ignores future data',
      () {
    final now = DateTime(2026, 11, 6, 12);
    CompletedWorkout w(int day) => CompletedWorkout(
        id: '$day',
        name: 'Session',
        date: DateTime(2026, 11, day, 9),
        plannedMinutes: 30);
    expect(ownedWorkoutStreak([w(5), w(5), w(4), w(7)], now), 2);
    expect(ownedWorkoutStreak([w(1)], now), 0);
  });
  test('Export writes a real JSON file and stale exports are cancelled',
      () async {
    final dir = await Directory.systemTemp.createTemp('allen-export-test-');
    addTearDown(() => dir.delete(recursive: true));
    await repo.createUserProfile(profile('a'));
    final service = ProfileExportService(directory: () async => dir);
    final file = await service.export(
        owner: 'a', repository: repo, active: () => owner == 'a');
    expect(jsonDecode(await file.readAsString())['userId'], 'a');
    final gate = Completer<Directory>();
    final stale = ProfileExportService(directory: () => gate.future)
        .export(owner: 'a', repository: repo, active: () => owner == 'a');
    await Future<void>.delayed(Duration.zero);
    owner = 'b';
    gate.complete(dir);
    await expectLater(stale, throwsA(isA<ProfileStorageException>()));
    expect(await dir.list().length, 1);
  });
}
