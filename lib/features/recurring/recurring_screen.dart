import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/money.dart';
import '../../shared/widgets/empty_state.dart';
import 'recurring_editor_sheet.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            tooltip: 'New recurring',
            icon: const Icon(Icons.add),
            onPressed: () => RecurringEditorSheet.show(context),
          ),
        ],
      ),
      body: StreamBuilder<List<RecurringTemplate>>(
        stream: db.watchRecurring(),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.repeat,
              title: 'No recurring items',
              message: 'Add rent, salary, subscriptions… then log them in one '
                  'tap when due.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [for (final r in items) _RecurringCard(r: r)],
          );
        },
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({required this.r});
  final RecurringTemplate r;

  String get _dueLabel {
    final now = DateTime.now();
    final due = DateTime(r.nextDueDate.year, r.nextDueDate.month,
        r.nextDueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    return 'Due in $diff days';
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = r.type == TxType.income;
    final overdue = r.nextDueDate.isBefore(DateTime.now());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Text(
                  '${isIncome ? "+" : "−"}${Money.format(r.amountMinor)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color:
                          isIncome ? MunshiTheme.positive : Colors.white),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      if (context.mounted) {
                        RecurringEditorSheet.show(context, existing: r);
                      }
                    } else if (v == 'delete') {
                      await db.deleteRecurring(r.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (overdue ? MunshiTheme.negative : MunshiTheme.accent)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_dueLabel · ${r.frequency.name}',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            overdue ? MunshiTheme.negative : MunshiTheme.accent),
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await db.logRecurringNow(r);
                    messenger.showSnackBar(SnackBar(
                      content: Text('Logged ${r.name}'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Log now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
