import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/money.dart';
import '../../shared/widgets/empty_state.dart';
import '../recurring/recurring_editor_sheet.dart';

/// A read-through of recurring *expenses* as subscriptions/bills, with a
/// normalized monthly cost projection.
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  /// Normalize any frequency to an approximate monthly cost (in minor units).
  static int monthlyMinor(RecurringTemplate r) {
    switch (r.frequency) {
      case Frequency.daily:
        return (r.amountMinor * 30.44).round();
      case Frequency.weekly:
        return (r.amountMinor * 4.345).round();
      case Frequency.monthly:
        return r.amountMinor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            tooltip: 'New subscription',
            icon: const Icon(Icons.add),
            onPressed: () => RecurringEditorSheet.show(context),
          ),
        ],
      ),
      body: StreamBuilder<List<RecurringTemplate>>(
        stream: db.watchSubscriptions(),
        builder: (context, snap) {
          final subs = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (subs.isEmpty) {
            return const EmptyState(
              icon: Icons.subscriptions_outlined,
              title: 'No subscriptions',
              message: 'Add recurring expenses like Netflix, Spotify, rent or '
                  'your gym — Munshi projects the monthly cost and reminds you '
                  'when each renews.',
            );
          }
          final monthlyTotal =
              subs.fold<int>(0, (s, r) => s + monthlyMinor(r));
          final yearlyTotal = monthlyTotal * 12;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _TotalCard(
                  monthly: monthlyTotal,
                  yearly: yearlyTotal,
                  count: subs.length),
              const SizedBox(height: 16),
              Text('Upcoming renewals',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: context.cFaint)),
              const SizedBox(height: 8),
              for (final r in subs) _SubCard(sub: r),
            ],
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard(
      {required this.monthly, required this.yearly, required this.count});
  final int monthly;
  final int yearly;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Costs you every month',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: Colors.white60)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$count active',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.white54)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(Money.format(monthly),
              style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('≈ ${Money.format(yearly)} per year',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.sub});
  final RecurringTemplate sub;

  String get _dueLabel {
    final now = DateTime.now();
    final due =
        DateTime(sub.nextDueDate.year, sub.nextDueDate.month, sub.nextDueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Renews today';
    if (diff == 1) return 'Renews tomorrow';
    if (diff <= 45) return 'Renews in $diff days';
    return 'Renews ${Money.dateLabel(sub.nextDueDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = sub.nextDueDate.isBefore(DateTime.now());
    final monthly = SubscriptionsScreen.monthlyMinor(sub);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => RecurringEditorSheet.show(context, existing: sub),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: MunshiTheme.accent.withValues(alpha: 0.15),
                child: const Icon(Icons.autorenew, color: MunshiTheme.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '$_dueLabel · ${sub.frequency.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: overdue
                              ? MunshiTheme.negative
                              : context.cMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Money.format(sub.amountMinor),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (sub.frequency != Frequency.monthly)
                    Text('≈${Money.format(monthly)}/mo',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: context.cFaint)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
