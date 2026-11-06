import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../widgets/profile_components.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.notifications});
  final NotificationService? notifications;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  late final _notifications = widget.notifications ?? NotificationService();
  NotificationPermission? _permission;
  bool _busy = false;
  String? _message;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status();
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _status();
  }

  Future<void> _status() async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final p = await _notifications.permissionStatus();
      if (mounted && request == _request) setState(() => _permission = p);
    } catch (_) {
      if (mounted && request == _request) {
        setState(
            () => _message = 'Notification status couldn’t be checked. Retry.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _action(bool test) async {
    if (_busy) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (test) {
        final sent = await _notifications.sendTestNotification();
        if (mounted && request == _request) {
          setState(() => _message = sent
              ? 'Test notification sent. If it is not visible, check Android notification channel settings.'
              : 'Allow notifications in Android settings before sending a test.');
        }
      } else {
        final p = await _notifications.requestPermission();
        if (mounted && request == _request) setState(() => _permission = p);
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _message =
            'Notifications couldn’t be updated. Check Android settings and retry.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ProfileScaffold(title: 'Settings', children: [
        const ProfileSection('Appearance'),
        const ProfileGroup(children: [
          ProfileRow(
              icon: Icons.dark_mode_outlined,
              title: 'Theme',
              value: 'Midnight Navy'),
          ProfileRow(
              icon: Icons.palette_outlined,
              title: 'Accent color',
              subtitle: 'Electric Blue',
              trailing: Tooltip(
                  message: 'Electric Blue',
                  child: CircleAvatar(
                      radius: 12, backgroundColor: AppColors.primary))),
        ]),
        const ProfileSection('Preferences'),
        ProfileGroup(children: [
          ProfileRow(
              icon: Icons.notifications_none,
              title: 'Notifications',
              subtitle: _permission == NotificationPermission.allowed
                  ? 'Allowed by Android'
                  : _permission == NotificationPermission.denied
                      ? 'Not allowed by Android'
                      : _permission == NotificationPermission.unavailable
                          ? 'Unavailable on this platform'
                          : 'Checking permission…',
              trailing: IconButton(
                  tooltip: 'Refresh notification status',
                  onPressed: _busy ? null : _status,
                  icon: const Icon(Icons.refresh))),
          const ProfileRow(
              icon: Icons.straighten, title: 'Units', value: 'Metric (kg, cm)'),
          const ProfileRow(
              icon: Icons.language, title: 'Language', value: 'English'),
        ]),
        const SizedBox(height: 12),
        const Text(
            'Notifications are managed by Android. Daily reminders are not scheduled. Any older reminder preference is not evidence of an active schedule.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (_permission == NotificationPermission.denied)
            OutlinedButton(
                onPressed: _busy ? null : () => _action(false),
                child: const Text('Allow notifications')),
          FilledButton(
              onPressed: _busy || _permission != NotificationPermission.allowed
                  ? null
                  : () => _action(true),
              child: const Text('Send test notification')),
        ]),
        if (_busy)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(
                  semanticsLabel: 'Checking notifications')),
        if (_message != null) ProfileFeedback(_message!),
        const ProfileSection('App experience'),
        ProfileGroup(children: [
          ProfileRow(
              icon: Icons.accessibility_new,
              title: 'Motion',
              subtitle: 'Allen respects system reduced-motion preferences.',
              value: MediaQuery.disableAnimationsOf(context) ||
                      MediaQuery.accessibleNavigationOf(context)
                  ? 'Reduced'
                  : 'System')
        ]),
        const SizedBox(height: 12),
        const Text(
            'Theme, accent, units and language are currently fixed. Additional customization and haptic controls are deferred.'),
      ]);
}
