import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../services/notification_service.dart';

/// Create or edit a reminder. Supports a custom daily time or an every-N-hours
/// interval.
class ReminderEditorSheet extends StatefulWidget {
  const ReminderEditorSheet({super.key, this.existing});

  final Reminder? existing;

  static Future<void> show(BuildContext context, {Reminder? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ReminderEditorSheet(existing: existing),
      ),
    );
  }

  @override
  State<ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<ReminderEditorSheet> {
  late TextEditingController _message;
  late ReminderMode _mode;
  late TimeOfDay _time;
  late int _interval;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _message =
        TextEditingController(text: e?.message ?? 'Log your spending');
    _mode = e?.mode ?? ReminderMode.dailyAt;
    _time = TimeOfDay(hour: e?.hour ?? 21, minute: e?.minute ?? 0);
    _interval = e?.intervalHours ?? 3;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final msg = _message.text.trim().isEmpty
        ? 'Log your spending'
        : _message.text.trim();
    final e = widget.existing;
    if (e == null) {
      final id = await db.insertReminder(RemindersCompanion.insert(
        message: Value(msg),
        mode: Value(_mode),
        hour: Value(_time.hour),
        minute: Value(_time.minute),
        intervalHours: Value(_interval),
      ));
      await NotificationService.instance.scheduleReminder(Reminder(
        id: id,
        message: msg,
        mode: _mode,
        hour: _time.hour,
        minute: _time.minute,
        intervalHours: _interval,
        isActive: true,
      ));
    } else {
      final updated = e.copyWith(
        message: msg,
        mode: _mode,
        hour: _time.hour,
        minute: _time.minute,
        intervalHours: _interval,
      );
      await db.updateReminder(updated);
      await NotificationService.instance.scheduleReminder(updated);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'New reminder' : 'Edit reminder',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              decoration: const InputDecoration(
                  labelText: 'Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ReminderMode>(
              segments: const [
                ButtonSegment(
                    value: ReminderMode.dailyAt,
                    icon: Icon(Icons.schedule, size: 16),
                    label: Text('Daily at')),
                ButtonSegment(
                    value: ReminderMode.hourly,
                    icon: Icon(Icons.timelapse, size: 16),
                    label: Text('Every N hrs')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            if (_mode == ReminderMode.dailyAt)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Time'),
                trailing: Text(_time.format(context),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                onTap: () async {
                  final picked = await showTimePicker(
                      context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
              )
            else
              Row(
                children: [
                  const Text('Every'),
                  Expanded(
                    child: Slider(
                      value: _interval.toDouble(),
                      min: 1,
                      max: 12,
                      divisions: 11,
                      label: '$_interval h',
                      onChanged: (v) =>
                          setState(() => _interval = v.round()),
                    ),
                  ),
                  Text('$_interval h'),
                ],
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
