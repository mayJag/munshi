import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/money.dart';
import '../dev/reminder_spike_sheet.dart';
import '../transactions/transaction_editor.dart';
import '../transactions/tx_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

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
          _NetBalanceHero(theme: theme),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MonthStat(
                  label: 'Spent this month',
                  type: TxType.expense,
                  from: monthStart,
                  to: monthEnd,
                  icon: Icons.trending_down,
                  color: MunshiTheme.negative,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MonthStat(
                  label: 'Income',
                  type: TxType.income,
                  from: monthStart,
                  to: monthEnd,
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
          const SizedBox(height: 4),
          _RecentList(),
        ],
      ),
    );
  }
}

class _NetBalanceHero extends StatelessWidget {
  const _NetBalanceHero({required this.theme});
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
          Text('Net balance',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          StreamBuilder<List<AccountBalance>>(
            stream: db.watchAccountBalances(),
            builder: (context, snap) {
              final net = (snap.data ?? const [])
                  .fold<int>(0, (s, b) => s + b.balanceMinor);
              return Text(Money.format(net),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ))
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scaleXY(begin: 0.95, end: 1);
            },
          ),
          const SizedBox(height: 4),
          Text('Across all your accounts',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({
    required this.label,
    required this.type,
    required this.from,
    required this.to,
    required this.icon,
    required this.color,
  });

  final String label;
  final TxType type;
  final DateTime from;
  final DateTime to;
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
            StreamBuilder<int>(
              stream: db.watchTotal(type, from, to),
              builder: (context, snap) => Text(
                Money.format(snap.data ?? 0),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(label,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TxWithRefs>>(
      stream: db.watchTransactions(limit: 6),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.inbox_outlined,
                      size: 40, color: Colors.white38),
                  const SizedBox(height: 12),
                  Text('No transactions yet',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white54)),
                  Text('Tap + to log your first one',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white38)),
                ],
              ),
            ),
          );
        }
        return Card(
          child: Column(
            children: [
              for (final item in items)
                TxTile(
                  item: item,
                  onTap: () =>
                      TransactionEditor.open(context, existing: item.tx),
                ),
            ],
          ),
        );
      },
    );
  }
}
