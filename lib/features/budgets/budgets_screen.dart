import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../services/settings_service.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';
import '../dashboard/allowance.dart';
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

  Future<void> _addBudget() async {
    final cats = (await db.allCategories())
        .where((c) => c.kind == TxType.expense)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Category>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Set a budget for…')),
            for (final c in cats)
              ListTile(
                leading: Icon(iconFor(c.iconKey), color: Color(c.colorValue)),
                title: Text(c.name),
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    await _editLine(BudgetLine(
      category: chosen,
      allocatedMinor: 0,
      spentMinor: 0,
      rolloverInMinor: 0,
      rolloverEnabled: false,
    ));
  }

  Future<void> _editMonthlyBudget(int? current) async {
    final ctrl = TextEditingController(
      text: current != null ? (current / 100).toStringAsFixed(0) : '',
    );
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_MonthlyBudgetAction>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Monthly Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set your total spending limit for this month.',
              style: TextStyle(color: context.cMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: const InputDecoration(
                labelText: 'Total limit',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _MonthlyBudgetAction.clear),
              child: const Text('Remove',
                  style: TextStyle(color: MunshiTheme.negative)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, _MonthlyBudgetAction.cancel),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _MonthlyBudgetAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == _MonthlyBudgetAction.clear) {
      await db.clearMonthlyBudget(_key);
      messenger.showSnackBar(const SnackBar(
        content: Text('Monthly budget removed'),
        behavior: SnackBarBehavior.floating,
      ));
    } else if (result == _MonthlyBudgetAction.save) {
      final minor = Money.toMinor(ctrl.text);
      if (minor > 0) {
        await db.setMonthlyBudget(_key, minor);
        messenger.showSnackBar(SnackBar(
          content: Text('Monthly budget set to ${Money.format(minor)}'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    ctrl.dispose();
  }

  Future<void> _clearMonth() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Clear ${Money.monthLabel(_month)} budgets?'),
        content: const Text('Removes all budget limits for this month.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await db.clearMonthBudgets(_key);
    await db.clearMonthlyBudget(_key);
    messenger.showSnackBar(const SnackBar(
      content: Text('Budgets cleared'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            tooltip: 'Add budget',
            icon: const Icon(Icons.add),
            onPressed: _addBudget,
          ),
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
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _clearMonth();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'clear', child: Text("Clear this month's budgets")),
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
            child: StreamBuilder<MonthlyBudget?>(
              stream: db.watchMonthlyBudget(_key),
              builder: (context, monthlySnap) {
                final monthlyBudget = monthlySnap.data;
                return StreamBuilder<List<BudgetLine>>(
                  stream: db.watchBudgetLines(_key),
                  builder: (context, snap) {
                    final lines = snap.data ?? const [];
                    if (snap.connectionState == ConnectionState.waiting &&
                        monthlySnap.connectionState ==
                            ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final withBudget =
                        lines.where((l) => l.hasBudget).toList();
                    final without =
                        lines.where((l) => !l.hasBudget).toList();
                    final totalSpent =
                        lines.fold<int>(0, (s, l) => s + l.spentMinor);
                    final categoryAllocated = withBudget.fold<int>(
                        0, (s, l) => s + l.availableMinor);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      children: [
                        _MonthlyTotalCard(
                          totalMinor: monthlyBudget?.totalMinor,
                          spentMinor: totalSpent,
                          categoryAllocatedMinor: categoryAllocated,
                          onEdit: () => _editMonthlyBudget(
                              monthlyBudget?.totalMinor),
                        ),
                        const SizedBox(height: 12),
                        _AllowancePanel(
                            monthKey: _key,
                            isCurrentMonth:
                                _key == Money.monthKey(DateTime.now())),
                        const SizedBox(height: 16),
                        if (withBudget.isNotEmpty) ...[
                          Text('Category breakdown',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: context.cFaint)),
                          const SizedBox(height: 8),
                        ] else
                          _EmptyHint(month: Money.monthLabel(_month)),
                        for (final l in withBudget)
                          _BudgetCard(line: l, onTap: () => _editLine(l)),
                        if (without.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Not budgeted',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: context.cFaint)),
                          const SizedBox(height: 8),
                          for (final l in without)
                            _UnbudgetedTile(
                                line: l, onTap: () => _editLine(l)),
                        ],
                      ],
                    );
                  },
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

/// Leftover-mode selector (spread vs save) + today's computed daily allowance.
class _AllowancePanel extends StatelessWidget {
  const _AllowancePanel(
      {required this.monthKey, required this.isCurrentMonth});
  final String monthKey;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily allowance',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('How unspent money each day is handled',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: context.cMuted)),
            const SizedBox(height: 12),
            ValueListenableBuilder<LeftoverMode>(
              valueListenable: SettingsService.instance.leftoverMode,
              builder: (context, mode, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<LeftoverMode>(
                      segments: const [
                        ButtonSegment(
                          value: LeftoverMode.spread,
                          icon: Icon(Icons.calendar_view_week, size: 16),
                          label: Text('Spread'),
                        ),
                        ButtonSegment(
                          value: LeftoverMode.savings,
                          icon: Icon(Icons.savings_outlined, size: 16),
                          label: Text('Save it'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => SettingsService.instance
                          .setLeftoverMode(s.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mode == LeftoverMode.spread
                          ? 'Leftover spreads across the remaining days, '
                              'raising future daily allowance.'
                          : 'Each day gets a fixed slice; whatever you don\'t '
                              'spend piles up as savings.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.cFaint),
                    ),
                    if (isCurrentMonth) ...[
                      const Divider(height: 24),
                      StreamBuilder<SpendSummary>(
                        stream: db.watchSpendSummary(monthKey),
                        builder: (context, snap) {
                          final s = snap.data;
                          if (s == null || s.budgetAllocatedMinor <= 0) {
                            return Text('Set budgets to get a daily number',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: context.cFaint));
                          }
                          final a = Allowance.compute(
                              summary: s, mode: mode, now: DateTime.now());
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _pill(theme, 'Spendable today',
                                  Money.format(a.canSpendTodayMinor),
                                  danger: a.canSpendTodayMinor < 0),
                              if (mode == LeftoverMode.savings)
                                _pill(theme, 'Saved',
                                    Money.format(a.savedMinor),
                                    good: true)
                              else
                                _pill(theme, 'Per day',
                                    Money.format(a.todayAllowanceMinor)),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(ThemeData theme, String label, String value,
      {bool danger = false, bool good = false}) {
    final color = danger
        ? MunshiTheme.negative
        : good
            ? MunshiTheme.positive
            : theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.62))),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

enum _MonthlyBudgetAction { save, clear, cancel }

/// Top card showing the overall monthly budget envelope.
/// When [totalMinor] is null the user hasn't set one yet — card prompts them.
class _MonthlyTotalCard extends StatelessWidget {
  const _MonthlyTotalCard({
    required this.totalMinor,
    required this.spentMinor,
    required this.categoryAllocatedMinor,
    required this.onEdit,
  });
  final int? totalMinor;
  final int spentMinor;
  final int categoryAllocatedMinor;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (totalMinor == null) {
      // No monthly budget set — show a tappable prompt.
      return GestureDetector(
        onTap: onEdit,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: MunshiTheme.accent.withValues(alpha: 0.35),
              width: 1.5,
            ),
            color: MunshiTheme.accent.withValues(alpha: 0.06),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MunshiTheme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: MunshiTheme.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Set a total monthly budget',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: MunshiTheme.accent,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      categoryAllocatedMinor > 0
                          ? 'You have ${Money.format(categoryAllocatedMinor)} in category limits — '
                              'add an overall cap too'
                          : 'Tap to set how much you want to spend this month',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.cFaint),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add, color: MunshiTheme.accent),
            ],
          ),
        ),
      );
    }

    final total = totalMinor!;
    final remaining = total - spentMinor;
    final over = spentMinor > total;
    final progress = total <= 0 ? 0.0 : (spentMinor / total).clamp(0.0, 1.0);
    final unallocated = total - categoryAllocatedMinor;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
                Text('Monthly budget',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: Colors.white70)),
                Icon(Icons.edit_outlined, size: 15, color: Colors.white38),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${Money.format(spentMinor)}  /  ${Money.format(total)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
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
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  over
                      ? 'Over by ${Money.format(-remaining)}'
                      : '${Money.format(remaining)} remaining',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: over ? MunshiTheme.negative : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unallocated > 0)
                  Text(
                    '${Money.format(unallocated)} unallocated',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white38),
                  ),
              ],
            ),
          ],
        ),
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
                          size: 14, color: context.cFaint),
                    ),
                  Text(
                    line.isOver
                        ? 'Over ${Money.format(-line.remainingMinor)}'
                        : '${Money.format(line.remainingMinor)} left',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: line.isOver
                          ? MunshiTheme.negative
                          : context.cMuted,
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
                  backgroundColor: context.cHair,
                  color: barColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${Money.format(line.spentMinor)} of '
                '${Money.format(line.availableMinor)}'
                '${line.rolloverInMinor > 0 ? " (incl. ${Money.format(line.rolloverInMinor)} rollover)" : ""}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: context.cFaint),
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
            Text(
              'Tap a category below to set a limit, or use ✨ up top to apply '
              'a starter template.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.cMuted, fontSize: 13),
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
