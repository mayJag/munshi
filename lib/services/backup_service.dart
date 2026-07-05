import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db.dart';
import 'settings_service.dart';

/// JSON snapshot backup + restore of all financial data.
///
/// Backups are written to `<app documents>/backups/`. Auto-backup (when the
/// setting is on) writes at most once per day on launch and prunes to the most
/// recent [_keep] files.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _keep = 7;

  Future<Directory> _backupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory(p.join(dir.path, 'backups'));
    if (!backups.existsSync()) backups.createSync(recursive: true);
    return backups;
  }

  /// Write a snapshot file and return it. [tag] is embedded in the filename.
  Future<File> writeBackup({String tag = 'manual'}) async {
    final snap = await db.exportSnapshot();
    final json = const JsonEncoder.withIndent('  ').convert(snap);
    final dir = await _backupDir();
    final now = DateTime.now();
    final stamp = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final file = File(p.join(dir.path, 'munshi_${tag}_$stamp.json'));
    await file.writeAsString(json);
    await SettingsService.instance.setLastBackupAt(now);
    await _prune();
    return file;
  }

  /// Runs a backup on launch if auto-backup is on and the last one is >20h old.
  Future<void> maybeAutoBackup() async {
    if (!SettingsService.instance.autoBackup) return;
    final last = SettingsService.instance.lastBackupAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(hours: 20)) {
      return;
    }
    try {
      await writeBackup(tag: 'auto');
    } catch (_) {/* never block launch on backup failure */}
  }

  Future<List<File>> listBackups() async {
    final dir = await _backupDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> _prune() async {
    final files = await listBackups();
    for (final f in files.skip(_keep)) {
      try {
        f.deleteSync();
      } catch (_) {/* ignore */}
    }
  }

  /// Parse a snapshot file and restore it (destructive — caller confirms).
  Future<void> restoreFromFile(String path) async {
    final content = await File(path).readAsString();
    final map = jsonDecode(content) as Map<String, dynamic>;
    await db.restoreSnapshot(map);
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
