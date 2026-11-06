import 'package:allen/fitness/models/progress_model.dart';
import 'package:allen/fitness/models/progress_tracking_data.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress_data_test.dart' show weight, meal;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? owner;
  late ProgressRepository repo;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    owner = 'member';
    repo = ProgressRepository(authenticatedUser: () => owner);
  });
  test('New weights retain model metadata, ownership and exact dated value',
      () async {
    final now = DateTime.now().subtract(const Duration(days: 3));
    await repo.addWeightEntry(WeightEntry(
        id: 'stable',
        userId: 'member',
        weight: 72.4,
        date: now,
        createdAt: now,
        notes: 'After breakfast'));
    final raw = (await LocalStorageService().getWeights()).single;
    expect(raw, {
      'id': 'stable',
      'userId': 'member',
      'weight': 72.4,
      'date': now.toIso8601String(),
      'createdAt': now.toIso8601String(),
      'notes': 'After breakfast'
    });
    expect((await repo.getWeightEntries('other')), isEmpty);
    expect((await repo.getLatestWeight('member'))!.weight, 72.4);
  });
  test(
      'Legacy/foreign records stay unchanged and are excluded rather than assigned',
      () async {
    final date =
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
    final legacy = {
      'weight': 72.4,
      'date': date,
      'legacyExtra': {'keep': true}
    };
    final foreign = {
      'id': 'foreign',
      'userId': 'other',
      'weight': 80,
      'date': date,
      'createdAt': date,
      'unknown': 'keep'
    };
    await LocalStorageService().saveWeights([legacy, foreign]);
    expect(await repo.getWeightEntries('member'), isEmpty);
    expect(await repo.getLatestWeight('member'), isNull);
    await repo.addWeightEntry(weight('owned', 71, DateTime.now()));
    final records = await LocalStorageService().getWeights();
    expect(records[1], legacy);
    expect(records[2], foreign);
    expect((await repo.getWeightEntries('member')).map((e) => e.id), ['owned']);
  });
  test(
      'Session mismatch, signed-out write, and forged foreign owner are rejected',
      () async {
    final entry = weight('owned', 70, DateTime.now());
    owner = 'other';
    await expectLater(
        repo.addWeightEntry(entry), throwsA(isA<ProgressStorageException>()));
    owner = null;
    await expectLater(
        repo.addWeightEntry(entry), throwsA(isA<ProgressStorageException>()));
    expect(await LocalStorageService().getWeights(), isEmpty);
    // The production default also fails closed without an initialized Firebase session.
    await expectLater(ProgressRepository().addWeightEntry(entry),
        throwsA(isA<ProgressStorageException>()));
  });
  test(
      'Edit preserves stored identity/owner/creation and unknown fields, including all legacy data',
      () async {
    final old = DateTime.now().subtract(const Duration(days: 8));
    await repo.addWeightEntry(weight('owned', 70, old));
    final raw = await LocalStorageService().getWeights();
    raw.single['extra'] = 'keep';
    raw.add({'weight': 90, 'date': old.toIso8601String()});
    await LocalStorageService().saveWeights(raw);
    await repo.updateWeightEntry(WeightEntry(
        id: 'owned',
        userId: 'member',
        weight: 71,
        date: old.add(const Duration(days: 1)),
        createdAt: DateTime.now(),
        notes: 'Corrected'));
    final stored = await LocalStorageService().getWeights();
    expect(stored.first['id'], 'owned');
    expect(stored.first['userId'], 'member');
    expect(stored.first['createdAt'], old.toIso8601String());
    expect(stored.first['extra'], 'keep');
    expect(stored[1], raw[1]);
    expect((await repo.getWeightEntries('member')).single.notes, 'Corrected');
  });
  test(
      'Editing another account ID, legacy ID, or transferring ownership cannot overwrite data',
      () async {
    final date = DateTime.now();
    await repo.addWeightEntry(weight('owned', 70, date));
    owner = 'other';
    await repo.addWeightEntry(weight('foreign', 80, date, owner: 'other'));
    owner = 'member';
    final raw = await LocalStorageService().getWeights();
    raw.add({'id': 'legacy', 'weight': 90, 'date': date.toIso8601String()});
    await LocalStorageService().saveWeights(raw);
    final before = (await SharedPreferences.getInstance()).getString('weights');
    for (final id in ['foreign', 'legacy', 'missing', '']) {
      await expectLater(repo.updateWeightEntry(weight(id, 99, date)),
          throwsA(isA<ProgressStorageException>()));
      await expectLater(repo.deleteWeightEntry(id, userId: 'member'),
          throwsA(isA<ProgressStorageException>()));
    }
    await expectLater(
        repo.updateWeightEntry(weight('owned', 99, date, owner: 'other')),
        throwsA(isA<ProgressStorageException>()));
    expect(
        (await SharedPreferences.getInstance()).getString('weights'), before);
  });
  test(
      'Session changes prevent subsequent edits and deletion, no write is reassigned',
      () async {
    final date = DateTime.now();
    await repo.addWeightEntry(weight('owned', 70, date));
    owner = 'other';
    await expectLater(repo.updateWeightEntry(weight('owned', 71, date)),
        throwsA(isA<ProgressStorageException>()));
    await expectLater(repo.deleteWeightEntry('owned'),
        throwsA(isA<ProgressStorageException>()));
    expect((await repo.getWeightEntries('member')).single.weight, 70);
    expect(await repo.getWeightEntries('other'), isEmpty);
  });
  test(
      'Concurrent creation retries save a stable draft once and preserve other entries',
      () async {
    final date = DateTime.now();
    final entry = weight('draft', 70, date);
    await Future.wait([
      repo.addWeightEntry(entry),
      repo.addWeightEntry(entry),
      repo.addWeightEntry(weight('other', 71, date))
    ]);
    expect((await repo.getWeightEntries('member')).length, 2);
  });
  test(
      'Edit and date survive a fresh preference cache/repository, deletion selects exactly one owned UUID',
      () async {
    final date = DateTime.now().subtract(const Duration(days: 1));
    await repo.addWeightEntry(weight('a', 70, date));
    await repo.addWeightEntry(weight('b', 71, date));
    await repo.updateWeightEntry(weight('a', 72, date));
    final encoded =
        (await SharedPreferences.getInstance()).getString('weights')!;
    SharedPreferences.setMockInitialValues({'weights': encoded});
    final fresh = ProgressRepository(authenticatedUser: () => owner);
    expect(
        (await fresh.getWeightEntries('member'))
            .singleWhere((e) => e.id == 'a')
            .weight,
        72);
    await fresh.deleteWeightEntry('a');
    expect((await fresh.getWeightEntries('member')).single.id, 'b');
  });
  test(
      'Corrupt owned weights surface errors, not empty history; foreign malformed fields do not leak',
      () async {
    await LocalStorageService().saveWeights([
      {'userId': 'other', 'weight': 'broken'}
    ]);
    expect(await repo.getWeightEntries('member'), isEmpty);
    await LocalStorageService().saveWeights([
      {'userId': 'member', 'weight': 'broken'}
    ]);
    await expectLater(repo.getWeightEntries('member'),
        throwsA(isA<ProgressStorageException>()));
    final data = await repo.loadTracking('member');
    expect(data.weights, isNull);
    expect(data.unavailable, contains(ProgressSource.weights));
    expect(data.meals, isEmpty);
    expect(data.workouts, isEmpty);
  });
  test(
      'Tracking reads beyond 100 weights/50 meals, filters actual workout owners and completed flags',
      () async {
    final now = DateTime.now();
    await LocalStorageService().saveWeights([
      for (var i = 0; i < 150; i++)
        {
          'id': 'w$i',
          'userId': 'member',
          'weight': 70 + i * .01,
          'date': now.subtract(Duration(days: i)).toIso8601String(),
          'createdAt': now.toIso8601String()
        }
    ]);
    await LocalStorageService().saveWorkouts([
      {
        'id': 'done',
        'userId': 'member',
        'completed': true,
        'name': 'Legs',
        'date': now.toIso8601String(),
        'durationMinutes': 30
      },
      {'id': 'pending', 'userId': 'member', 'completed': false},
      {'id': 'foreign', 'userId': 'other', 'completed': true},
      {'id': 'legacy', 'completed': true},
    ]);
    for (var i = 0; i < 55; i++) {
      await MealRepository().createMeal(meal('m$i', now));
    }
    final data = await repo.loadTracking('member');
    expect(data.weights!.length, 150);
    expect(data.meals!.length, 55);
    expect(data.workouts!.single.id, 'done');
    expect((await repo.getProgressStats('member'))['totalWorkouts'], 1);
  });
  test(
      'Missing/mismatched profile cannot invent targets; water remains shared and excluded',
      () async {
    await LocalStorageService().saveUserProfile(
        {'id': 'other', 'targetCalories': 2000, 'targetProtein': 100});
    await LocalStorageService().addWater(250);
    final data = await repo.loadTracking('member');
    expect(data.goals!.calories, isNull);
    expect(data.goals!.protein, isNull);
    expect(await repo.getTodayWaterIntake('other'), 250);
    expect(await repo.getTodayWaterIntake('member'), 250);
  });
  test(
      'Invalid weight values and future dates are rejected without affecting stored records',
      () async {
    for (final value in [double.nan, double.infinity, 0.0, -1.0, 1001.0]) {
      await expectLater(
          repo.addWeightEntry(weight('invalid', value, DateTime.now())),
          throwsA(isA<ProgressStorageException>()));
    }
    await expectLater(
        repo.addWeightEntry(
            weight('future', 70, DateTime.now().add(const Duration(days: 1)))),
        throwsA(isA<ProgressStorageException>()));
    expect(await LocalStorageService().getWeights(), isEmpty);
  });
  test(
      'Editing preserves exact UTC creation metadata and nullable Home/Profile compatibility on read errors',
      () async {
    final created = DateTime.now()
        .subtract(const Duration(days: 2))
        .toUtc()
        .toIso8601String();
    await LocalStorageService().saveWeights([
      {
        'id': 'utc',
        'userId': 'member',
        'weight': 70,
        'date': created,
        'createdAt': created
      }
    ]);
    await repo.updateWeightEntry(weight('utc', 71, DateTime.now()));
    expect((await LocalStorageService().getWeights()).single['createdAt'],
        created);
    await (await SharedPreferences.getInstance())
        .setString('weights', 'broken-json');
    expect(await repo.getLatestWeight('member'), isNull);
    await expectLater(repo.getWeightEntries('member'),
        throwsA(isA<ProgressStorageException>()));
  });
}
