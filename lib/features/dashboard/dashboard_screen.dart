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
          // ── Header ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Munshi',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(Money.monthLabel(now),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.cMuted)),
                ],
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                icon: const CircleAvatar(
                  backgroundColor: MunshiTheme.surfaceHigh,
                  child: Icon(Icons.settings_outlined, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Main budget hero ─────────────────────────────────────────────
          _BudgetHero(monthKey: monthKey),
          const SizedBox(height: 14),

          // ── Net balance + Income row ─────────────────────────────────────
          Row(
            children: [
              Expanded(child: _NetBalanceCard()),
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

          // ── Recent activity ──────────────────────────────────────────────
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

// ── Budget hero ─────────────────────────────────────────────────────────────

/// The main home-screen card. When a budget exists it shows spent/remaining/
/// daily breakdown. When there's no budget it falls back to net balance.
class _BudgetHero extends StatelessWidget {
  const _BudgetHero({required this.monthKey});
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
            if (summary == null || summary.budgetAllocatedMinor <= 0) {
              return const _NetBalanceHero();
            }
            final a = Allowance.compute(
                summary: summary, mode: mode, now: DateTime.now());
            return _BudgetCard(summary: summary, allowance: a, mode: mode);
          },
        );
      },
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard(
      {required this.summary,
      required this.allowance,
      required this.mode});
  final SpendSummary summary;
  final Allowance allowance;
  final LeftoverMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = summary.budgetAllocatedMinor;
    final spent = summary.spentMonthMinor;
    final remaining = budget - spent;
    final over = spent > budget;
    final progress = (spent / budget).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: over
              ? const [Color(0xFF7F1D1D), Color(0xFF3B0B0B)]
              : MunshiTheme.heroGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: label + remaining pill ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly budget',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: Colors.white60)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: over
                      ? MunshiTheme.negative.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  over
                      ? 'Over by ${Money.format(-remaining)}'
                      : '${Money.format(remaining)} left',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: over ? MunshiTheme.negative : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Spent / Budget ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Money.format(spent),
                      style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800, color: Colors.white))
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scaleXY(begin: 0.95, end: 1),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('of ${Money.format(budget)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white54)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Progress bar ────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: over ? MunshiTheme.negative : MunshiTheme.accent,
            ),
          ),
          const SizedBox(height: 14),

          // ── Daily allowance row ─────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.today_outlined,
                    size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today\'s allowance',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white38)),
                      Text(
                        Money.format(allowance.todayAllowanceMinor),
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: allowance.canSpendTodayMinor < 0
                                ? MunshiTheme.negative
                                : Colors.white),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Can spend now',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white38)),
                    Text(
                      allowance.canSpendTodayMinor < 0
                          ? '−${Money.format(-allowance.canSpendTodayMinor)}'
                          : Money.format(allowance.canSpendTodayMinor),
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: allowance.canSpendTodayMinor < 0
                              ? MunshiTheme.negative
                              : MunshiTheme.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Recalculated allowance (spread mode, after spending today) ──
          if (mode == LeftoverMode.spread &&
              allowance.daysAfterToday > 0 &&
              summary.spentTodayMinor > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (allowance.overspentToday
                        ? MunshiTheme.negative
                        : MunshiTheme.accent)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.autorenew,
                      size: 16,
                      color: allowance.overspentToday
                          ? MunshiTheme.negative
                          : MunshiTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white70),
                        children: [
                          TextSpan(
                            text: allowance.overspentToday
                                ? 'Over by '
                                    '${Money.format(-allowance.canSpendTodayMinor)} '
                                    'today — new allowance '
                                : 'Recalculated to ',
                          ),
                          TextSpan(
                            text:
                                '${Money.format(allowance.nextDaysAllowanceMinor)}/day',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: allowance.overspentToday
                                    ? MunshiTheme.negative
                                    : MunshiTheme.accent),
                          ),
                          TextSpan(
                            text: ' for the next ${allowance.daysAfterToday} '
                                '${allowance.daysAfterToday == 1 ? "day" : "days"}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // ── Days left caption ───────────────────────────────────────
          Text(
            '${allowance.daysLeftInclusive} '
            '${allowance.daysLeftInclusive == 1 ? "day" : "days"} left '
            'in ${Money.monthLabel(DateTime.now())} · '
            '${mode == LeftoverMode.spread ? "Spread" : "Save it"} mode',
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _NetBalanceHero extends StatelessWidget {
  const _NetBalanceHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<AccountBalance>>(
      stream: db.watchAccountBalances(),
      builder: (context, snap) {
        final net = (snap.data ?? const [])
            .fold<int>(0, (s, b) => s + b.balanceMinor);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: MunshiTheme.heroGradient,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Net balance',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: Colors.white60)),
              const SizedBox(height: 8),
              Text(Money.format(net),
                      style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800, color: Colors.white))
                  .animate()
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 4),
              Text('Set a budget to see daily allowance',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white38)),
            ],
          ),
        );
      },
    );
  }
}

// ── Stat cards ───────────────────────────────────────────────────────────────

class _NetBalanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<AccountBalance>>(
      stream: db.watchAccountBalances(),
      builder: (context, snap) {
        final net = (snap.data ?? const [])
            .fold<int>(0, (s, b) => s + b.balanceMinor);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: MunshiTheme.accent, size: 20),
                const SizedBox(height: 12),
                Text(Money.format(net),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('Net balance',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.cMuted)),
              ],
            ),
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
                    theme.textTheme.bodySmall?.copyWith(color: context.cMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Recent transactions ──────────────────────────────────────────────────────

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
                  Icon(Icons.inbox_outlined,
                      size: 40, color: context.cFaint),
                  const SizedBox(height: 12),
                  Text('No transactions yet',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: context.cMuted)),
                  Text('Tap + to log your first one',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.cFaint)),
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
