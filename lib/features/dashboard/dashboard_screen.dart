import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../services/settings_service.dart';
import '../../shared/money.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction_editor.dart';
import '../transactions/tx_tile.dart';
import 'allowance.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final monthKey = Money.monthKey(now);

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
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SettingsScreen())),
                icon: CircleAvatar(
                  backgroundColor: MunshiTheme.surfaceHigh,
                  child: const Icon(Icons.settings_outlined,
                      color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Hero(monthKey: monthKey),
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
          const SizedBox(height: 12),
          _NetBalanceStat(),
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

/// Safe-to-spend-today hero, driven by budget + leftover mode. Falls back to
/// net balance when no budget is set for the month.
class _Hero extends StatelessWidget {
  const _Hero({required this.monthKey});
  final String monthKey;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LeftoverMode>(
      valueListenable: SettingsService.instance.leftoverMode,
      builder: (context, mode, _) {
        return StreamBuilder<SpendSummary>(
          stream: db.watchSpendSummary(monthKey),
          builder: (context, snap) {
            final summary = snap.data;
            if (summary == null) {
              return const _HeroShell(
                  label: 'Safe to spend today', value: '…', sub: '');
            }
            final a = Allowance.compute(
                summary: summary, mode: mode, now: DateTime.now());
            if (!a.hasBudget) return const _NetBalanceHero();

            final canSpend = a.canSpendTodayMinor;
            final sub = mode == LeftoverMode.savings
                ? 'Saved this month: ${Money.format(a.savedMinor)}'
                : 'Spreads unspent across ${a.daysLeftInclusive} '
                    '${a.daysLeftInclusive == 1 ? "day" : "days"} left';
            return _HeroShell(
              label: 'Safe to spend today',
              value: Money.format(canSpend),
              sub: '$sub · ${Money.format(a.todayAllowanceMinor)}/day',
              danger: canSpend < 0,
            );
          },
        );
      },
    );
  }
}

class _HeroShell extends StatelessWidget {
  const _HeroShell({
    required this.label,
    required this.value,
    required this.sub,
    this.danger = false,
  });
  final String label;
  final String value;
  final String sub;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: danger
              ? const [Color(0xFF7F1D1D), Color(0xFF3B0B0B)]
              : const [MunshiTheme.accentDeep, Color(0xFF0B3B36)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  theme.textTheme.labelLarge?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(value,
                  style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800, color: Colors.white))
              .animate()
              .fadeIn(duration: 400.ms)
              .scaleXY(begin: 0.95, end: 1),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          ],
        ],
      ),
    );
  }
}

class _NetBalanceHero extends StatelessWidget {
  const _NetBalanceHero();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AccountBalance>>(
      stream: db.watchAccountBalances(),
      builder: (context, snap) {
        final net =
            (snap.data ?? const []).fold<int>(0, (s, b) => s + b.balanceMinor);
        return _HeroShell(
          label: 'Net balance',
          value: Money.format(net),
          sub: 'Set a budget to see your daily number',
        );
      },
    );
  }
}

class _NetBalanceStat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<AccountBalance>>(
      stream: db.watchAccountBalances(),
      builder: (context, snap) {
        final net =
            (snap.data ?? const []).fold<int>(0, (s, b) => s + b.balanceMinor);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined,
                color: MunshiTheme.accent),
            title: const Text('Net balance'),
            trailing: Text(Money.format(net),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
        );
      },
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
