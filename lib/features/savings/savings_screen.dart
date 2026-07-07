import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';
import '../../shared/widgets/empty_state.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings goals'),
        actions: [
          IconButton(
            tooltip: 'New goal',
            icon: const Icon(Icons.add),
            onPressed: () => _GoalEditor.show(context),
          ),
        ],
      ),
      body: StreamBuilder<List<SavingsGoal>>(
        stream: db.watchSavingsGoals(),
        builder: (context, snap) {
          final goals = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (goals.isEmpty) {
            return const EmptyState(
              icon: Icons.savings_outlined,
              title: 'No savings goals yet',
              message: 'Set a target for a trip, a phone, or an emergency '
                  'fund — then add money as you save.',
            );
          }
          final totalTarget =
              goals.fold<int>(0, (s, g) => s + g.targetMinor);
          final totalSaved = goals.fold<int>(0, (s, g) => s + g.savedMinor);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _OverviewCard(saved: totalSaved, target: totalTarget),
              const SizedBox(height: 16),
              for (final g in goals) _GoalCard(goal: g),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.saved, required this.target});
  final int saved;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
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
          Text('Total saved',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: Colors.white60)),
          const SizedBox(height: 6),
          Text(Money.format(saved),
              style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('of ${Money.format(target)} across all goals',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white54)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: MunshiTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(goal.colorValue);
    final pct =
        goal.targetMinor <= 0 ? 0.0 : (goal.savedMinor / goal.targetMinor);
    final complete = goal.savedMinor >= goal.targetMinor && goal.targetMinor > 0;
    final remaining = (goal.targetMinor - goal.savedMinor).clamp(0, 1 << 62);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _GoalEditor.show(context, existing: goal),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _ProgressRing(progress: pct.clamp(0.0, 1.0), color: color,
                  icon: iconFor(goal.iconKey), complete: complete),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(goal.name,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert,
                              size: 18, color: context.cFaint),
                          onSelected: (v) async {
                            if (v == 'edit') {
                              _GoalEditor.show(context, existing: goal);
                            } else if (v == 'delete') {
                              await db.deleteSavingsGoal(goal.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete',
                                    style: TextStyle(
                                        color: MunshiTheme.negative))),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '${Money.format(goal.savedMinor)} of '
                      '${Money.format(goal.targetMinor)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.cMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      complete
                          ? '🎉 Goal reached!'
                          : '${Money.format(remaining)} to go'
                              '${_deadlineLabel()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: complete ? MunshiTheme.positive : color,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _contribute(context, goal, false),
                            icon: const Icon(Icons.remove, size: 16),
                            label: const Text('Withdraw'),
                            style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _contribute(context, goal, true),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add money'),
                            style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _deadlineLabel() {
    if (goal.targetDate == null) return '';
    final d = goal.targetDate!;
    final now = DateTime.now();
    final days = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days < 0) return ' · past due';
    if (days == 0) return ' · due today';
    if (days <= 60) return ' · $days days left';
    return ' · by ${Money.dateLabel(d)}';
  }

  Future<void> _contribute(
      BuildContext context, SavingsGoal g, bool add) async {
    final ctrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(add ? 'Add to ${g.name}' : 'Withdraw from ${g.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(add ? 'Add' : 'Withdraw')),
        ],
      ),
    );
    if (ok != true) return;
    final minor = Money.toMinor(ctrl.text);
    if (minor <= 0) return;
    await db.contributeToGoal(g.id, add ? minor : -minor);
    messenger.showSnackBar(SnackBar(
      content: Text(
          '${add ? "Added" : "Withdrew"} ${Money.format(minor)} '
          '${add ? "to" : "from"} ${g.name}'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

/// Circular progress indicator with a centered icon.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.icon,
    required this.complete,
  });
  final double progress;
  final Color color;
  final IconData icon;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: color.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(
                  complete ? MunshiTheme.positive : color),
            ),
          ),
          Icon(complete ? Icons.check : icon,
              color: complete ? MunshiTheme.positive : color, size: 22),
        ],
      ),
    );
  }
}

/// Add / edit a savings goal.
class _GoalEditor extends StatefulWidget {
  const _GoalEditor({this.existing});
  final SavingsGoal? existing;

  static Future<void> show(BuildContext context, {SavingsGoal? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _GoalEditor(existing: existing),
      ),
    );
  }

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late TextEditingController _name;
  late TextEditingController _target;
  late String _iconKey;
  late int _color;
  DateTime? _targetDate;

  static const _swatches = [
    0xFF2DD4BF, 0xFF3B82F6, 0xFFF97316, 0xFFEC4899,
    0xFF8B5CF6, 0xFF22C55E, 0xFFEAB308, 0xFFEF4444,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _target = TextEditingController(
        text: e == null ? '' : (e.targetMinor / 100).toStringAsFixed(0));
    _iconKey = e?.iconKey ?? 'savings';
    _color = e?.colorValue ?? _swatches.first;
    _targetDate = e?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = Money.toMinor(_target.text);
    if (name.isEmpty || target <= 0) return;
    final e = widget.existing;
    if (e == null) {
      await db.insertSavingsGoal(SavingsGoalsCompanion.insert(
        name: name,
        targetMinor: target,
        iconKey: Value(_iconKey),
        colorValue: Value(_color),
        targetDate: Value(_targetDate),
      ));
    } else {
      await db.updateSavingsGoal(e.copyWith(
        name: name,
        targetMinor: target,
        iconKey: _iconKey,
        colorValue: _color,
        targetDate: Value(_targetDate),
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'New goal' : 'Edit goal',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Goal name (e.g. Goa trip)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _target,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Icon',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: context.cMuted)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final k in kGoalIconKeys)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _iconKey = k),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: _iconKey == k
                              ? Color(_color).withValues(alpha: 0.25)
                              : MunshiTheme.surfaceHigh,
                          child: Icon(iconFor(k),
                              color: _iconKey == k
                                  ? Color(_color)
                                  : Colors.white54),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Colour',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: context.cMuted)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final c in _swatches)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c
                                ? context.cText
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate ??
                      DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Target date (optional)',
                  border: const OutlineInputBorder(),
                  suffixIcon: _targetDate == null
                      ? const Icon(Icons.calendar_today, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _targetDate = null),
                        ),
                ),
                child: Text(
                  _targetDate == null
                      ? 'No deadline'
                      : Money.dateLabel(_targetDate!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Save goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
