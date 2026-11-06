import 'dart:async';
import 'package:allen/fitness/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  bool allowed = false;
  int shows = 0, requests = 0;
  Completer<void>? pending;
  String? body;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    allowed = false;
    shows = 0;
    requests = 0;
    pending = null;
    body = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'areNotificationsEnabled':
          return allowed;
        case 'requestNotificationsPermission':
          requests++;
          allowed = true;
          return true;
        case 'show':
          shows++;
          body = (call.arguments as Map)['body'];
          if (pending != null) await pending!.future;
          return null;
        default:
          return null;
      }
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  NotificationService service() =>
      NotificationService.withPlugin(FlutterLocalNotificationsPlugin());
  test('Permission status and explicit request reflect Android plugin',
      () async {
    final notifications = service();
    expect(
        await notifications.permissionStatus(), NotificationPermission.denied);
    expect(await notifications.requestPermission(),
        NotificationPermission.allowed);
    expect(requests, 1);
    expect(shows, 0);
  });
  test('Test notification is not sent without permission', () async {
    expect(await service().sendTestNotification(), isFalse);
    expect(shows, 0);
  });
  test('Explicit test sends once and rejects overlapping requests', () async {
    allowed = true;
    pending = Completer<void>();
    final notifications = service();
    final first = notifications.sendTestNotification();
    while (shows == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(await notifications.sendTestNotification(), isFalse);
    pending!.complete();
    expect(await first, isTrue);
    expect(shows, 1);
    expect(body, contains('not scheduled'));
  });
  test(
      'Unsupported daily scheduling fails explicitly rather than showing an immediate reminder',
      () async {
    final notifications = service();
    await expectLater(
        notifications.scheduleDailyNotification(
            id: 1, title: 'daily', body: 'daily', hour: 9, minute: 0),
        throwsUnsupportedError);
    expect(shows, 0);
    expect(await notifications.isWorkoutReminderEnabled(), isFalse);
  });
}
