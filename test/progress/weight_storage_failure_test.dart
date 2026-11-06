import 'dart:async';
import 'dart:convert';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress_data_test.dart' show weight;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  late Map<String, Object> disk;
  String? owner;
  bool reject = false,
      throwWrite = false,
      writeThenReject = false,
      failRead = false;
  Completer<bool>? acknowledgment;
  setUp(() {
    SharedPreferences.resetStatic();
    disk = {};
    owner = 'member';
    reject = false;
    throwWrite = false;
    writeThenReject = false;
    failRead = false;
    acknowledgment = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') {
        if (failRead) throw PlatformException(code: 'private-read');
        return Map<String, Object>.from(disk);
      }
      if (call.method == 'setString') {
        if (throwWrite) throw PlatformException(code: 'private-write');
        if (reject) return false;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        disk[args['key'] as String] = args['value'] as String;
        if (acknowledgment != null) return await acknowledgment!.future;
        return !writeThenReject;
      }
      throw StateError('Unexpected preferences call');
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
  });
  ProgressRepository repo() =>
      ProgressRepository(authenticatedUser: () => owner);
  for (final throwing in [false, true]) {
    test(
        'Native weight failure is visible and cannot create a cached phantom ($throwing)',
        () async {
      reject = !throwing;
      throwWrite = throwing;
      final entry = weight('draft', 70, DateTime.now());
      await expectLater(repo().addWeightEntry(entry), throwsA(anything));
      expect(disk, isEmpty);
      expect(await repo().getWeightEntries('member'), isEmpty);
      reject = false;
      throwWrite = false;
      await repo().addWeightEntry(entry);
      expect((await repo().getWeightEntries('member')).single.id, 'draft');
    });
  }
  test(
      'Lost acknowledgment retries existing ID once and reconciles an edited value',
      () async {
    writeThenReject = true;
    final date = DateTime.now();
    await expectLater(
        repo().addWeightEntry(weight('draft', 70, date)), throwsA(anything));
    expect((await repo().getWeightEntries('member')).single.weight, 70);
    writeThenReject = false;
    await repo().addWeightEntry(weight('draft', 71, date));
    await repo().updateWeightEntry(weight('draft', 71, date));
    SharedPreferences.resetStatic();
    final values = await repo().getWeightEntries('member');
    expect(values.length, 1);
    expect(values.single.weight, 71);
  });
  test(
      'Uncertain cached weights cannot confirm a retry until native reload succeeds',
      () async {
    await SharedPreferences.getInstance();
    reject = true;
    failRead = true;
    final entry = weight('draft', 70, DateTime.now());
    await expectLater(repo().addWeightEntry(entry), throwsA(anything));
    reject = false;
    await expectLater(repo().addWeightEntry(entry), throwsA(anything));
    expect(disk, isEmpty);
    failRead = false;
    await repo().addWeightEntry(entry);
    expect((await repo().getWeightEntries('member')).single.id, 'draft');
  });
  test('Queued writes recheck live ownership before reading and persisting',
      () async {
    acknowledgment = Completer<bool>();
    final date = DateTime.now();
    final first = repo().addWeightEntry(weight('first', 70, date));
    while (disk.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final queued = repo().addWeightEntry(weight('queued', 71, date));
    final rejection =
        expectLater(queued, throwsA(isA<ProgressStorageException>()));
    owner = 'other';
    acknowledgment!.complete(true);
    await first;
    await rejection;
    final records = jsonDecode(disk['flutter.weights'] as String) as List;
    expect(records.length, 1);
    expect(records.single['id'], 'first');
    expect(records.single['userId'], 'member');
    expect(await repo().getWeightEntries('other'), isEmpty);
  });
  test(
      'Concurrent edit failure preserves legacy and last confirmed owned value',
      () async {
    final date = DateTime.now();
    await repo().addWeightEntry(weight('owned', 70, date));
    final raw = await LocalStorageService().getWeights();
    raw.add({'weight': 90, 'date': date.toIso8601String(), 'legacy': 'keep'});
    await LocalStorageService().saveWeights(raw);
    reject = true;
    await expectLater(
        repo().updateWeightEntry(weight('owned', 71, date)), throwsA(anything));
    expect((await repo().getWeightEntries('member')).single.weight, 70);
    expect((await LocalStorageService().getWeights()).last, raw.last);
  });
}
