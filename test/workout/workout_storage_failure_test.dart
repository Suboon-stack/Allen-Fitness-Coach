import 'package:allen/fitness/repositories/workout_repository.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'workout_repository_test.dart' show sampleWorkout;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  late Map<String, Object> disk;
  var failWrite = false;
  var throwWrite = false;
  var failRead = false;
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
        final arguments = Map<String, dynamic>.from(call.arguments as Map);
        disk[arguments['key'] as String] = arguments['value'] as String;
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
  test('A false platform save is surfaced and a retry writes the record once',
      () async {
    failWrite = true;
    final repo = WorkoutRepository();
    final workout = sampleWorkout('stable-id');
    await expectLater(repo.createWorkout(workout), throwsStateError);
    expect(disk, isEmpty);
    expect(await LocalStorageService().getWorkouts(), isEmpty);
    failWrite = false;
    expect(await repo.createWorkout(workout), 'stable-id');
    expect(disk['flutter.workouts'], contains('stable-id'));
    SharedPreferences.resetStatic();
    expect((await WorkoutRepository().getUserWorkouts('member')).single.id,
        'stable-id');
  });
  test('An exception during completion preserves the actual incomplete record',
      () async {
    final repo = WorkoutRepository();
    await repo.createWorkout(sampleWorkout('stable-id'));
    throwWrite = true;
    await expectLater(repo.markWorkoutComplete('stable-id', true),
        throwsA(isA<PlatformException>()));
    expect((await repo.getUserWorkouts('member')).single.completed, isFalse);
    throwWrite = false;
    await repo.markWorkoutComplete('stable-id', true);
    SharedPreferences.resetStatic();
    expect(
        (await WorkoutRepository().getUserWorkouts('member')).single.completed,
        isTrue);
  });
  test('An unreadable cache after a failed save cannot falsely confirm a retry',
      () async {
    await SharedPreferences.getInstance();
    failWrite = true;
    failRead = true;
    final repo = WorkoutRepository();
    final workout = sampleWorkout('stable-id');
    await expectLater(repo.createWorkout(workout), throwsStateError);
    failWrite = false;
    await expectLater(
        repo.createWorkout(workout), throwsA(isA<PlatformException>()));
    expect(disk, isEmpty);
    failRead = false;
    await repo.createWorkout(workout);
    expect((await repo.getUserWorkouts('member')), hasLength(1));
    expect(disk['flutter.workouts'], contains('stable-id'));
  });
}
