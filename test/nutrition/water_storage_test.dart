import 'dart:async';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  late Map<String, Object> disk;
  Completer<bool>? acknowledgement;
  var rejectWrite = false,
      writeThenReject = false,
      throwWrite = false,
      failRead = false;
  String key() =>
      'flutter.water_${DateTime.now().toIso8601String().substring(0, 10)}';
  setUp(() {
    SharedPreferences.resetStatic();
    disk = {};
    acknowledgement = null;
    rejectWrite = false;
    writeThenReject = false;
    throwWrite = false;
    failRead = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') {
        if (failRead) throw PlatformException(code: 'read-failed');
        return Map<String, Object>.from(disk);
      }
      if (call.method == 'setInt') {
        if (throwWrite) throw PlatformException(code: 'write-failed');
        if (rejectWrite) return false;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        disk[args['key'] as String] = args['value'] as int;
        if (acknowledgement != null) return await acknowledgement!.future;
        return !writeThenReject;
      }
      throw StateError('Unexpected preferences method: ${call.method}');
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
  });
  test(
      'Concurrent additions serialize without lost increments, using the existing daily key',
      () async {
    await Future.wait([
      ProgressRepository().addWaterIntake('member', 100),
      ProgressRepository().addWaterIntake('member', 250),
      ProgressRepository().addWaterIntake('member', 500)
    ]);
    expect(disk, {key(): 850});
    SharedPreferences.resetStatic();
    expect(await LocalStorageService().getTodayWater(), 850);
    // Storage still has one shared total: no fabricated entry history/ownership.
    expect(await ProgressRepository().getTodayWaterIntake('another'), 850);
  });
  for (final throwing in [false, true]) {
    test(
        'Failed native write does not fabricate an increased total ($throwing)',
        () async {
      disk[key()] = 100;
      rejectWrite = !throwing;
      throwWrite = throwing;
      await expectLater(LocalStorageService().addWater(250),
          throwsA(isA<WaterStorageException>()));
      expect(await LocalStorageService().getTodayWater(), 100);
      rejectWrite = false;
      throwWrite = false;
      await LocalStorageService().addWater(250);
      expect(disk[key()], 350);
    });
  }
  test(
      'Lost acknowledgement is reconciled against disk instead of inviting duplicate logging',
      () async {
    writeThenReject = true;
    await LocalStorageService().addWater(250);
    expect(disk[key()], 250);
    expect(await LocalStorageService().getTodayWater(), 250);
    writeThenReject = false;
    await LocalStorageService().addWater(100);
    expect(disk[key()], 350);
  });
  test(
      'Failed reload blocks uncertain cached totals until native read recovers',
      () async {
    await SharedPreferences.getInstance();
    rejectWrite = true;
    failRead = true;
    await expectLater(LocalStorageService().addWater(100),
        throwsA(isA<WaterStorageException>()));
    await expectLater(LocalStorageService().getTodayWater(), throwsA(anything));
    rejectWrite = false;
    failRead = false;
    expect(await LocalStorageService().getTodayWater(), 0);
    await LocalStorageService().addWater(250);
    expect(disk[key()], 250);
  });
  test(
      'Invalid stored water and invalid additions are rejected without rewriting records',
      () async {
    disk[key()] = -50;
    await expectLater(LocalStorageService().getTodayWater(),
        throwsA(isA<WaterStorageException>()));
    await expectLater(LocalStorageService().addWater(100),
        throwsA(isA<WaterStorageException>()));
    expect(disk[key()], -50);
    await expectLater(LocalStorageService().addWater(0), throwsArgumentError);
    await expectLater(LocalStorageService().addWater(-1), throwsArgumentError);
  });
  test(
      'Water reads wait for native acknowledgement rather than optimistic cache',
      () async {
    acknowledgement = Completer<bool>();
    final write = LocalStorageService().addWater(100);
    await Future<void>.delayed(Duration.zero);
    var readCompleted = false;
    final read = LocalStorageService().getTodayWater().then((value) {
      readCompleted = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(readCompleted, isFalse);
    acknowledgement!.complete(true);
    await write;
    expect(await read, 100);
  });
}
