import 'package:allen/fitness/repositories/meal_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'meal_repository_test.dart' show sampleMeal;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  late Map<String, Object> disk;
  var failWrite = false, throwWrite = false, failRead = false;
  setUp(() {
    SharedPreferences.resetStatic();
    disk = {};
    failWrite = false;
    throwWrite = false;
    failRead = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') {
        if (failRead) throw PlatformException(code: 'read-failed');
        return Map<String, Object>.from(disk);
      }
      if (call.method == 'setString') {
        if (throwWrite) throw PlatformException(code: 'write-failed');
        if (failWrite) return false;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        disk[args['key'] as String] = args['value'] as String;
        return true;
      }
      throw StateError('Unexpected preferences method: ${call.method}');
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
  });
  for (final throwing in [false, true]) {
    test(
        'Failed native meal save does not become a successful cached save ($throwing)',
        () async {
      final repo = MealRepository();
      failWrite = !throwing;
      throwWrite = throwing;
      await expectLater(
          repo.createMeal(sampleMeal('stable')), throwsA(anything));
      expect(disk, isEmpty);
      expect(await repo.getUserMeals('member'), isEmpty);
      failWrite = false;
      throwWrite = false;
      await repo.createMeal(sampleMeal('stable'));
      SharedPreferences.resetStatic();
      expect(
          (await MealRepository().getUserMeals('member')).single.id, 'stable');
    });
  }
  test('Uncertain cache must reload before a retry may confirm a meal',
      () async {
    await SharedPreferences.getInstance();
    failWrite = true;
    failRead = true;
    final repo = MealRepository();
    await expectLater(repo.createMeal(sampleMeal('stable')), throwsA(anything));
    failWrite = false;
    await expectLater(repo.createMeal(sampleMeal('stable')), throwsA(anything));
    expect(disk, isEmpty);
    failRead = false;
    await repo.createMeal(sampleMeal('stable'));
    expect((await repo.getUserMeals('member')).length, 1);
  });
}
