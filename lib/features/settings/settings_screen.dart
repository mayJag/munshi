import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../categories/categories_screen.dart';
import '../dev/reminder_spike_sheet.dart';
import '../recurring/recurring_screen.dart';
import '../reminders/reminders_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Manage'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categories'),
            subtitle: const Text('Add or edit your own categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _go(context, const CategoriesScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Recurring'),
            subtitle: const Text('Rent, salary, subscriptions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _go(context, const RecurringScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Reminders'),
            subtitle: const Text('Nudges at a custom time'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _go(context, const RemindersScreen()),
          ),
          const _SectionLabel('Daily allowance'),
          ValueListenableBuilder<LeftoverMode>(
            valueListenable: SettingsService.instance.leftoverMode,
            builder: (context, mode, _) {
              return RadioGroup<LeftoverMode>(
                groupValue: mode,
                onChanged: (v) =>
                    SettingsService.instance.setLeftoverMode(v!),
                child: const Column(
                  children: [
                    RadioListTile<LeftoverMode>(
                      value: LeftoverMode.spread,
                      title: Text('Spread leftover'),
                      subtitle: Text(
                          'Unspent money raises the coming days\' allowance'),
                    ),
                    RadioListTile<LeftoverMode>(
                      value: LeftoverMode.savings,
                      title: Text('Save leftover'),
                      subtitle: Text(
                          'Fixed daily slice; leftovers pile up as savings'),
                    ),
                  ],
                ),
              );
            },
          ),
          const _SectionLabel('Developer'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Reminder spike (test notifications)'),
            onTap: () => ReminderSpikeSheet.show(context),
          ),
          const _SectionLabel('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Munshi'),
            subtitle: Text(
                'Offline-first personal finance. Your money, in order.'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Colors.white38, fontWeight: FontWeight.w700)),
    );
  }
}
