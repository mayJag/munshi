import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../services/backup_service.dart';
import '../../services/settings_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  List<File> _backups = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final list = await BackupService.instance.listBackups();
    if (mounted) setState(() => _backups = list);
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await BackupService.instance.writeBackup();
      await _refresh();
      messenger.showSnackBar(SnackBar(
        content: Text('Backed up · ${p.basename(file.path)}'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(File f) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], text: 'Munshi backup'),
    );
  }

  Future<void> _restore() async {
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'Munshi backup', extensions: ['json']),
    ]);
    if (file == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
            'This replaces ALL current data (accounts, transactions, budgets, '
            'goals) with the contents of the backup. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await BackupService.instance.restoreFromFile(file.path);
      messenger.showSnackBar(const SnackBar(
        content: Text('Restored. Restart the app to see all changes.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Restore failed: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = SettingsService.instance.lastBackupAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.backup_outlined),
            title: const Text('Auto-backup'),
            subtitle: Text(last == null
                ? 'Off · never backed up'
                : 'Daily on open · last ${_ago(last)}'),
            value: SettingsService.instance.autoBackup,
            onChanged: (v) async {
              await SettingsService.instance.setAutoBackup(v);
              if (v) await BackupService.instance.writeBackup(tag: 'auto');
              await _refresh();
              if (mounted) setState(() {});
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Back up now'),
            subtitle: const Text('Write a fresh snapshot to device storage'),
            trailing: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _busy ? null : _backupNow,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from file'),
            subtitle: const Text('Replace all data from a .json backup'),
            onTap: _busy ? null : _restore,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 6),
            child: Text('On-device backups',
                style: TextStyle(
                    color: Colors.white38, fontWeight: FontWeight.w700)),
          ),
          if (_backups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No backups yet.',
                  style: TextStyle(color: Colors.white38)),
            )
          else
            for (final f in _backups)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(p.basename(f.path),
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(_sizeLabel(f)),
                trailing: IconButton(
                  icon: const Icon(Icons.ios_share, size: 20),
                  onPressed: () => _share(f),
                ),
              ),
        ],
      ),
    );
  }

  String _sizeLabel(File f) {
    final kb = f.lengthSync() / 1024;
    return '${kb.toStringAsFixed(1)} KB';
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
