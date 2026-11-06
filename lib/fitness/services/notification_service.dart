import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationPermission { allowed, denied, unavailable }

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal()
      : _notifications = FlutterLocalNotificationsPlugin();
  NotificationService.withPlugin(FlutterLocalNotificationsPlugin plugin)
      : _notifications = plugin;
  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;
  Future<void>? _initializing;
  bool _testing = false;
  Future<void> initialize() async {
    if (_initialized) return;
    final pending = _initializing;
    if (pending != null) return pending;
    final task = _initialize();
    _initializing = task;
    try {
      await task;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    await _notifications.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _initialized = true;
  }

  Future<NotificationPermission> permissionStatus() async {
    await initialize();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await android?.areNotificationsEnabled();
    return enabled == null
        ? NotificationPermission.unavailable
        : enabled
            ? NotificationPermission.allowed
            : NotificationPermission.denied;
  }

  Future<NotificationPermission> requestPermission() async {
    await initialize();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return NotificationPermission.unavailable;
    await android.requestNotificationsPermission();
    return permissionStatus();
  }

  Future<bool> sendTestNotification() async {
    if (_testing) return false;
    _testing = true;
    try {
      if (await permissionStatus() != NotificationPermission.allowed) {
        return false;
      }
      await showNotification(
          id: 1,
          title: 'Allen notification test',
          body:
              'Notifications are available. Daily reminders are not scheduled.');
      return true;
    } finally {
      _testing = false;
    }
  }

  Future<void> showNotification(
      {required int id, required String title, required String body}) async {
    await initialize();
    await _notifications.show(
        id,
        title,
        body,
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'allen_fitness', 'Allen Fitness',
                channelDescription: 'Fitness notifications',
                importance: Importance.high,
                priority: Priority.high)));
  }

  // Retained API for existing callers. This implementation cannot schedule
  // notifications, so fail explicitly instead of pretending an immediate alert
  // is a recurring reminder. Existing preferences remain untouched.
  Future<void> scheduleDailyNotification(
      {required int id,
      required String title,
      required String body,
      required int hour,
      required int minute}) async {
    throw UnsupportedError('Daily scheduling is not available.');
  }

  Future<void> toggleWorkoutReminder(bool enabled) async {
    if (enabled) throw UnsupportedError('Daily scheduling is not available.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('workout_reminder_enabled', false);
    await _notifications.cancel(1);
  }

  Future<bool> isWorkoutReminderEnabled() async => false;
  Future<void> cancelAllNotifications() => _notifications.cancelAll();
  Future<void> cancelNotification(int id) => _notifications.cancel(id);
}
