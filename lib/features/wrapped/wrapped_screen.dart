import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';

/// A "Wrapped"-style recap of a single month's spending.
class WrappedScreen extends StatelessWidget {
  const WrappedScreen({super.key, required this.monthKey});
  final String monthKey;

  static Future<void> open(BuildContext context, String monthKey) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WrappedScreen(monthKey: monthKey)),
    );
  }

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  @override
  Widget build(BuildContext context) {
    final month = AppDatabase.monthStart(monthKey);
    return Scaffold(
      appBar: AppBar(title: Text('${Money.monthLabel(month)} Wrapped')),
      body: FutureBuilder<MonthWrapped>(
        future: db.monthWrapped(monthKey),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final w = snap.data!;
          if (w.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 48, color: context.cHair),
                    const SizedBox(height: 16),
                    Text('Nothing to wrap for ${Money.monthLabel(month)}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: context.cMuted)),
                    const SizedBox(height: 8),
                    Text('Log some expenses and check back.',
                        style: TextStyle(color: context.cFaint)),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: _cards(context, w, month)
                .animate(interval: 80.ms)
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.1, end: 0),
          );
        },
      ),
    );
  }

  List<Widget> _cards(BuildContext context, MonthWrapped w, DateTime month) {
    final cards = <Widget>[
      _HeroCard(
        title: 'You spent',
        value: Money.format(w.spentMinor),
        sub: '${w.txnCount} transaction${w.txnCount == 1 ? "" : "s"} · '
            '${Money.format(w.dailyAverageMinor)}/day average',
        colors: MunshiTheme.heroGradient,
      ),
    ];

    final mom = w.momChange;
    if (mom != null) {
      final up = mom > 0;
      cards.add(_StatCard(
        icon: up ? Icons.trending_up : Icons.trending_down,
        color: up ? MunshiTheme.negative : MunshiTheme.positive,
        label: 'vs last month',
        value: '${up ? "+" : ""}${mom.toStringAsFixed(0)}%',
        detail: up
            ? 'You spent more than last month'
            : 'Nice — less than last month',
      ));
    }

    if (w.topCategory != null) {
      final share = w.spentMinor <= 0
          ? 0
          : (w.topCategoryMinor / w.spentMinor * 100).round();
      cards.add(_StatCard(
        icon: iconFor(w.topCategory!.iconKey),
        color: Color(w.topCategory!.colorValue),
        label: 'Top category',
        value: w.topCategory!.name,
        detail: '${Money.format(w.topCategoryMinor)} · $share% of spending',
      ));
    }

    if (w.biggestExpense != null) {
      final b = w.biggestExpense!;
      final label = b.note?.isNotEmpty == true
          ? b.note!
          : (w.biggestExpenseCategory?.name ?? 'Expense');
      cards.add(_StatCard(
        icon: Icons.local_fire_department,
        color: const Color(0xFFF97316),
        label: 'Biggest single expense',
        value: Money.format(b.amountMinor),
        detail: '$label · ${Money.dateLabel(b.occurredAt)}',
      ));
    }

    if (w.busiestDayOfMonth != null) {
      cards.add(_StatCard(
        icon: Icons.event,
        color: const Color(0xFF8B5CF6),
        label: 'Busiest day',
        value: '${Money.monthLabel(month).split(" ").first} '
            '${w.busiestDayOfMonth}',
        detail: '${Money.format(w.busiestDayMinor)} spent that day',
      ));
    }

    if (w.topWeekday != null) {
      cards.add(_StatCard(
        icon: Icons.calendar_view_week,
        color: const Color(0xFF3B82F6),
        label: 'Your spendiest weekday',
        value: _weekdays[w.topWeekday! - 1],
        detail: 'You tend to spend most on this day',
      ));
    }

    if (w.incomeMinor > 0) {
      final net = w.incomeMinor - w.spentMinor;
      cards.add(_StatCard(
        icon: net >= 0 ? Icons.savings : Icons.warning_amber,
        color: net >= 0 ? MunshiTheme.positive : MunshiTheme.negative,
        label: net >= 0 ? 'You saved' : 'You overspent',
        value: Money.format(net.abs()),
        detail: 'Income ${Money.format(w.incomeMinor)} − '
            'spending ${Money.format(w.spentMinor)}',
      ));
    }

    return cards;
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.value,
    required this.sub,
    required this.colors,
  });
  final String title;
  final String value;
  final String sub;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 8),
          Text(sub,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: context.cFaint,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(detail,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.cMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
