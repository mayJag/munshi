import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';
import '../dev/reminder_spike_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Munshi',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Your money, in order',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white54)),
                ],
              ),
              IconButton(
                tooltip: 'Reminder spike (dev)',
                onPressed: () => ReminderSpikeSheet.show(context),
                icon: CircleAvatar(
                  backgroundColor: MunshiTheme.surfaceHigh,
                  child: const Icon(Icons.notifications_active_outlined,
                      color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SafeToSpendCard(theme: theme),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Spent this month',
                  value: '₹0',
                  icon: Icons.trending_down,
                  color: MunshiTheme.negative,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Income',
                  value: '₹0',
                  icon: Icons.trending_up,
                  color: MunshiTheme.positive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Recent activity',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.inbox_outlined,
                      size: 40, color: Colors.white38),
                  const SizedBox(height: 12),
                  Text('No transactions yet',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white54)),
                  Text('Tap + to log your first one',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white38)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeToSpendCard extends StatelessWidget {
  const _SafeToSpendCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MunshiTheme.accentDeep, Color(0xFF0B3B36)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Safe to spend today',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text('₹0',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ))
              .animate()
              .fadeIn(duration: 500.ms)
              .scaleXY(begin: 0.9, end: 1),
          const SizedBox(height: 4),
          Text('Set a budget to see your daily number',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
