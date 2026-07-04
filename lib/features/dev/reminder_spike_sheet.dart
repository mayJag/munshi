import 'package:flutter/material.dart';

import '../../services/notification_service.dart';

/// Phase-0 Spike 2 harness. A dev-only sheet to exercise every notification
/// path on a real device: permissions, immediate fire, scheduled, hourly
/// repeat, daily-at-time, and reboot survival (reboot the phone after
/// scheduling, then confirm pending list / that it still fires).
class ReminderSpikeSheet extends StatelessWidget {
  const ReminderSpikeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ReminderSpikeSheet(),
    );
  }

  void _toast(ScaffoldMessengerState messenger, String msg) {
    messenger.showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = NotificationService.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reminder spike (dev)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Verify notifications on a real device.',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn(context, 'Request permissions', (m) async {
                  final ok = await svc.requestPermissions();
                  _toast(m, ok ? 'Notifications allowed' : 'Denied');
                }),
                _btn(context, 'Fire now', (m) async {
                  await svc.showTestNow();
                  _toast(m, 'Fired');
                }),
                _btn(context, 'In 10 seconds', (m) async {
                  await svc.scheduleInSeconds(10);
                  _toast(m, 'Scheduled +10s');
                }),
                _btn(context, 'Hourly repeat', (m) async {
                  await svc.scheduleHourly();
                  _toast(m, 'Hourly scheduled');
                }),
                _btn(context, 'Daily 9:00', (m) async {
                  await svc.scheduleDailyAt(9, 0);
                  _toast(m, 'Daily 09:00 scheduled');
                }),
                _btn(context, 'Show pending', (m) async {
                  final p = await svc.pending();
                  _toast(m, '${p.length} pending: '
                      '${p.map((e) => e.id).join(", ")}');
                }),
                _btn(context, 'Cancel all', (m) async {
                  await svc.cancelAll();
                  _toast(m, 'Cancelled');
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(
    BuildContext context,
    String label,
    Future<void> Function(ScaffoldMessengerState) action,
  ) {
    // Capture the messenger synchronously so it's safe to use after awaits.
    final messenger = ScaffoldMessenger.of(context);
    return FilledButton.tonal(
      onPressed: () => action(messenger),
      child: Text(label),
    );
  }
}
