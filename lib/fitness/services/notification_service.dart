import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'allen_fitness',
      'Allen Fitness',
      channelDescription: 'Fitness reminders and notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(id, title, body, details);
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notif_${id}_hour', hour);
    await prefs.setInt('notif_${id}_minute', minute);

    await _notifications.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'allen_notifications',
            'Allen Notifications',
            channelDescription: 'Fitness notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ));
  }

  Future<void> toggleWorkoutReminder(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('workout_reminder_enabled', enabled);
    if (enabled) {
      await showNotification(
        id: 1,
        title: 'Workout Reminder Enabled 💪',
        body: 'You\'ll receive daily workout reminders',
      );
    } else {
      await _notifications.cancel(1);
    }
  }

  Future<bool> isWorkoutReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('workout_reminder_enabled') ?? false;
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}
