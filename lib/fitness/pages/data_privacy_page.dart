import 'package:flutter/material.dart';
import '../../features/auth/data/user_repository.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../services/profile_export_service.dart';
import '../services/storage_service.dart';
import '../widgets/profile_components.dart';

class DataPrivacyPage extends StatelessWidget {
  const DataPrivacyPage({super.key, this.repository, this.exportService});
  final UserRepository? repository;
  final ProfileExportService? exportService;
  @override
  Widget build(BuildContext context) => AccountBoundary(
      builder: (context, user) => _DataPrivacy(
          user: user,
          repository: repository ?? UserRepository(),
          exportService: exportService ?? ProfileExportService()));
}

class _DataPrivacy extends StatefulWidget {
  const _DataPrivacy(
      {required this.user,
      required this.repository,
      required this.exportService});
  final AppUser user;
  final UserRepository repository;
  final ProfileExportService exportService;
  @override
  State<_DataPrivacy> createState() => _DataPrivacyState();
}

class _DataPrivacyState extends State<_DataPrivacy> {
  bool _busy = false;
  String? _message;
  bool get _active =>
      mounted && verifiedAccount(context)?.uid == widget.user.uid;
  Future<void> _export() async {
    if (_busy || !_active) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = await widget.exportService.export(
          owner: widget.user.uid,
          repository: widget.repository,
          active: () => _active);
      if (_active) {
        setState(() => _message =
            'Saved ${file.uri.pathSegments.last} in Allen’s private app Documents folder. This is not a Downloads or shared file. External sharing is not available yet. Exports are not encrypted and remain on this device until removed with app data.');
      }
    } catch (_) {
      if (_active) {
        setState(() => _message =
            'Export couldn’t be completed. Retry; your fitness records have not been changed.');
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _clearOlderCache() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Clear older weight cache?'),
                content: const Text(
                    'This keeps the existing clear operation: it removes the older weight_logs cache only. It does not delete current Progress weight history. The cache has no account ownership and may contain shared device records.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Clear cache'))
                ]));
    if (!_active || ok != true || _busy) return;
    setState(() => _busy = true);
    try {
      await StorageService().clearWeightLogs();
      if (_active) {
        setState(() => _message =
            'Older weight cache cleared. Current Progress history is unchanged.');
      }
    } catch (_) {
      if (_active) {
        setState(() => _message = 'The older cache couldn’t be cleared.');
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ProfileScaffold(title: 'Data & Privacy', children: [
        const ProfileSection('Stored on this device'),
        const ProfileGroup(children: [
          ProfileRow(
              icon: Icons.person_outline,
              title: 'Profile & personal targets',
              subtitle:
                  'New profiles use your Firebase account UID. A shared older profile is read only when its stored owner matches you.'),
          ProfileRow(
              icon: Icons.monitor_weight_outlined,
              title: 'Weight history',
              subtitle:
                  'Owned records appear in personal history. Unowned older records are preserved without being assigned to you.'),
          ProfileRow(
              icon: Icons.fitness_center,
              title: 'Workouts & meals',
              subtitle:
                  'Profile statistics and personal exports filter by account. Older workout screens still have legacy shared-storage limitations.'),
          ProfileRow(
              icon: Icons.water_drop_outlined,
              title: 'Water is shared device data',
              subtitle:
                  'Daily water totals have no account owner. They can be visible to another account on this device and are excluded from personal exports. Ownership migration is deferred.'),
        ]),
        const ProfileSection('AI & cloud services'),
        const Text(
            'Chat conversations and unconfirmed meal plans are temporary in Allen. Confirmed scanned meals are stored as AI estimates. Requests and photos are sent to Gemini when you use AI features. Firebase manages sign-in; local fitness records are not cloud-synchronized.'),
        const ProfileSection('Export your records'),
        const Text(
            'Export contains your matching profile, workouts, meals and weight records as JSON. Other accounts’ records, unowned legacy data, shared water totals and device preferences are excluded. This is an app-private file export, not a cloud backup or full device archive.'),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.download_outlined),
            label: Text(_busy ? 'Working…' : 'Export my data')),
        if (_busy)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(
                  semanticsLabel: 'Exporting account data')),
        if (_message != null) ProfileFeedback(_message!),
        const ProfileSection('Privacy limitations'),
        const Text(
            'Local records and exports use app storage without additional encryption. Signing out does not erase them. App backups and a compromised or shared device may expose local data. A Gemini key shipped in a client app remains extractable; moving AI requests to a protected backend is deferred.'),
        const SizedBox(height: 24),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Existing legacy cache control'),
            children: [
              const Text(
                  'Bulk deletion of current fitness records is not implemented here. The pre-existing older-cache clear operation is unchanged.'),
              TextButton(
                  onPressed: _busy ? null : _clearOlderCache,
                  child: const Text('Clear older weight cache')),
            ]),
      ]);
}
