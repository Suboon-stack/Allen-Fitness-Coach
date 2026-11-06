import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../features/auth/data/user_repository.dart';
import '../models/profile_overview_data.dart';

/// An explicit app-private JSON export. No native sharing plugin is installed.
/// The destination is injected in tests; personal files never overwrite another
/// account's previous export.
class ProfileExportService {
  ProfileExportService({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directory;
  Future<File> export(
      {required String owner,
      required UserRepository repository,
      required bool Function() active}) async {
    File? file;
    void check() {
      if (!active()) {
        throw const ProfileStorageException(
            'Your session changed. Export cancelled.');
      }
    }

    try {
      check();
      final data = await repository.exportUserData(owner);
      check();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final directory = await _directory();
      check();
      file = File('${directory.path}/allen_export_${const Uuid().v4()}.json');
      await file.writeAsString(json, flush: true);
      check();
      return file;
    } catch (_) {
      // Remove only this newly-created incomplete/stale export, never fitness
      // records or an existing export. Keep a fixed public error message.
      if (file != null) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      throw const ProfileStorageException(
          'Export couldn’t be completed. Your fitness records have not been changed.');
    }
  }
}
