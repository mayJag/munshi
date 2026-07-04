import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/empty_state.dart';
import 'reminder_editor_sheet.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            tooltip: 'Grant permission',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => NotificationService.instance.requestPermissions(),
          ),
          IconButton(
            tooltip: 'New reminder',
            icon: const Icon(Icons.add),
            onPressed: () => ReminderEditorSheet.show(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Reminder>>(
        stream: db.watchReminders(),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.alarm,
              title: 'No reminders',
              message: 'Add a nudge at a custom time so you never forget to '
                  'log an expense.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [for (final r in items) _ReminderTile(r: r)],
          );
        },
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.r});
  final Reminder r;

  String _subtitle(BuildContext context) {
    if (r.mode == ReminderMode.dailyAt) {
      final t = TimeOfDay(hour: r.hour, minute: r.minute);
      return 'Daily at ${t.format(context)}';
    }
    return 'Every ${r.intervalHours} hours';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => ReminderEditorSheet.show(context, existing: r),
        leading: Icon(
            r.mode == ReminderMode.dailyAt ? Icons.schedule : Icons.timelapse),
        title: Text(r.message),
        subtitle: Text(_subtitle(context)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: r.isActive,
              onChanged: (v) async {
                final updated = r.copyWith(isActive: v);
                await db.updateReminder(updated);
                await NotificationService.instance.scheduleReminder(updated);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'delete') {
                  await db.deleteReminder(r.id);
                  await NotificationService.instance.cancelReminder(r.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
