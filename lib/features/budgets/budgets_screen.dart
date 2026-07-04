import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';
import 'templates.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _key => Money.monthKey(_month);

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  Future<void> _applyTemplate(BudgetTemplate t) async {
    final messenger = ScaffoldMessenger.of(context);
    await db.applyTemplate(_key, t.minor);
    messenger.showSnackBar(SnackBar(
      content: Text('Applied "${t.name}" to ${Money.monthLabel(_month)}'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _editLine(BudgetLine line) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AllocationDialog(monthKey: _key, line: line),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          PopupMenuButton<BudgetTemplate>(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Starter templates',
            onSelected: _applyTemplate,
            itemBuilder: (_) => [
              for (final t in kBudgetTemplates)
                PopupMenuItem(
                  value: t,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.name),
                    subtitle: Text(t.blurb),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthNav(
            label: Money.monthLabel(_month),
            onPrev: () => _shift(-1),
            onNext: () => _shift(1),
          ),
          Expanded(
            child: StreamBuilder<List<BudgetLine>>(
              stream: db.watchBudgetLines(_key),
              builder: (context, snap) {
                final lines = snap.data ?? const [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final withBudget =
                    lines.where((l) => l.hasBudget).toList();
                final without =
                    lines.where((l) => !l.hasBudget).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    _SummaryCard(lines: withBudget),
                    const SizedBox(height: 16),
                    if (withBudget.isEmpty)
                      _EmptyHint(month: Money.monthLabel(_month)),
                    for (final l in withBudget)
                      _BudgetCard(line: l, onTap: () => _editLine(l)),
                    if (without.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Not budgeted',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: Colors.white38)),
                      const SizedBox(height: 8),
                      for (final l in without)
                        _UnbudgetedTile(line: l, onTap: () => _editLine(l)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav(
      {required this.label, required this.onPrev, required this.onNext});
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.lines});
  final List<BudgetLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allocated =
        lines.fold<int>(0, (s, l) => s + l.availableMinor);
    final spent = lines.fold<int>(0, (s, l) => s + l.spentMinor);
    final progress =
        allocated <= 0 ? 0.0 : (spent / allocated).clamp(0.0, 1.0);
    final over = spent > allocated && allocated > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MunshiTheme.accentDeep, Color(0xFF0B3B36)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spent of budget',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          Text('${Money.format(spent)}  /  ${Money.format(allocated)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: over ? MunshiTheme.negative : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.line, required this.onTap});
  final BudgetLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(line.category.colorValue);
    final barColor = line.isOver ? MunshiTheme.negative : color;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconFor(line.category.iconKey), color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(line.category.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (line.rolloverEnabled)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.loop,
                          size: 14, color: Colors.white38),
                    ),
                  Text(
                    line.isOver
                        ? 'Over ${Money.format(-line.remainingMinor)}'
                        : '${Money.format(line.remainingMinor)} left',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: line.isOver
                          ? MunshiTheme.negative
                          : Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: line.progress.toDouble(),
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  color: barColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${Money.format(line.spentMinor)} of '
                '${Money.format(line.availableMinor)}'
                '${line.rolloverInMinor > 0 ? " (incl. ${Money.format(line.rolloverInMinor)} rollover)" : ""}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnbudgetedTile extends StatelessWidget {
  const _UnbudgetedTile({required this.line, required this.onTap});
  final BudgetLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(line.category.colorValue);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(iconFor(line.category.iconKey), color: color, size: 20),
      title: Text(line.category.name),
      subtitle: line.spentMinor > 0
          ? Text('${Money.format(line.spentMinor)} spent')
          : null,
      trailing: const Text('Set budget',
          style: TextStyle(color: MunshiTheme.accent, fontSize: 13)),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.month});
  final String month;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_outlined,
                color: MunshiTheme.accent, size: 32),
            const SizedBox(height: 10),
            Text('No budgets for $month',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Tap a category below to set a limit, or use ✨ up top to apply '
              'a starter template.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edit one category's allocation + rollover for the month.
class _AllocationDialog extends StatefulWidget {
  const _AllocationDialog({required this.monthKey, required this.line});
  final String monthKey;
  final BudgetLine line;

  @override
  State<_AllocationDialog> createState() => _AllocationDialogState();
}

class _AllocationDialogState extends State<_AllocationDialog> {
  late TextEditingController _amount;
  late bool _rollover;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.line.allocatedMinor > 0
          ? (widget.line.allocatedMinor / 100).toStringAsFixed(0)
          : '',
    );
    _rollover = widget.line.rolloverEnabled;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.line.category.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly limit',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Roll over unspent'),
            subtitle: const Text('Carry surplus into next month'),
            value: _rollover,
            onChanged: (v) => setState(() => _rollover = v),
          ),
        ],
      ),
      actions: [
        if (widget.line.hasBudget)
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await db.clearBudget(widget.monthKey, widget.line.category.id);
              nav.pop();
            },
            child: const Text('Remove',
                style: TextStyle(color: MunshiTheme.negative)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            final minor = Money.toMinor(_amount.text);
            if (minor <= 0) {
              await db.clearBudget(widget.monthKey, widget.line.category.id);
            } else {
              await db.upsertBudget(
                monthKey: widget.monthKey,
                categoryId: widget.line.category.id,
                allocatedMinor: minor,
                rolloverEnabled: _rollover,
              );
            }
            nav.pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
