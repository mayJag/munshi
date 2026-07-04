import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';
import '../../shared/widgets/empty_state.dart';
import 'spend_calendar.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedCat;
  Map<int, Category> _catById = const {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await db.allCategories();
    if (!mounted) return;
    setState(() => _catById = {for (final c in cats) c.id: c});
  }

  void _shift(int by) => setState(() {
        _month = DateTime(_month.year, _month.month + by);
        _selectedCat = null;
      });

  DateTime get _monthStart => DateTime(_month.year, _month.month, 1);
  DateTime get _monthEnd => DateTime(_month.year, _month.month + 1, 1);
  DateTime get _windowStart => DateTime(_month.year, _month.month - 5, 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: Column(
        children: [
          _MonthNav(
            label: Money.monthLabel(_month),
            onPrev: () => _shift(-1),
            onNext: () => _shift(1),
          ),
          Expanded(
            child: StreamBuilder<List<TxRow>>(
              stream: db.watchTxInRange(_windowStart, _monthEnd,
                  type: TxType.expense),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? const [];
                final month = all
                    .where((t) =>
                        !t.occurredAt.isBefore(_monthStart) &&
                        t.occurredAt.isBefore(_monthEnd))
                    .toList();

                if (all.isEmpty) {
                  return const EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Nothing to analyze yet',
                    message:
                        'Log some expenses and charts will appear here.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    _sectionTitle('Calendar'),
                    SpendCalendar(
                      month: _month,
                      spentByDay: _byDay(month),
                      onTapDay: (d) => _showDay(context, d, month),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Where it went'),
                    _DonutCard(
                      byCategory: _byCategory(month),
                      catById: _catById,
                      selected: _selectedCat,
                      onSelect: (id) => setState(() => _selectedCat = id),
                    ),
                    const SizedBox(height: 24),
                    _DriversCard(monthKey: Money.monthKey(_month)),
                    const SizedBox(height: 24),
                    _sectionTitle('6-month trend'),
                    _TrendCard(byMonth: _byMonth(all)),
                    const SizedBox(height: 24),
                    _sectionTitle('By day of week'),
                    _WeekdayCard(byWeekday: _byWeekday(month)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );

  Map<int, int> _byDay(List<TxRow> month) {
    final m = <int, int>{};
    for (final t in month) {
      m[t.occurredAt.day] = (m[t.occurredAt.day] ?? 0) + t.amountMinor;
    }
    return m;
  }

  Map<int, int> _byCategory(List<TxRow> month) {
    final m = <int, int>{};
    for (final t in month) {
      final id = t.categoryId ?? -1;
      m[id] = (m[id] ?? 0) + t.amountMinor;
    }
    return m;
  }

  Map<String, int> _byMonth(List<TxRow> all) {
    final m = <String, int>{};
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(_month.year, _month.month - i, 1);
      m[Money.monthKey(d)] = 0;
    }
    for (final t in all) {
      final k = Money.monthKey(t.occurredAt);
      if (m.containsKey(k)) m[k] = m[k]! + t.amountMinor;
    }
    return m;
  }

  List<int> _byWeekday(List<TxRow> month) {
    final w = List<int>.filled(7, 0);
    for (final t in month) {
      w[t.occurredAt.weekday - 1] += t.amountMinor;
    }
    return w;
  }

  void _showDay(BuildContext context, int day, List<TxRow> month) {
    final items = month.where((t) => t.occurredAt.day == day).toList()
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    final total = items.fold<int>(0, (s, t) => s + t.amountMinor);
    final date = DateTime(_month.year, _month.month, day);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(Money.dateLabel(date),
                  style: Theme.of(context).textTheme.titleMedium),
              Text('${Money.format(total)} spent',
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Nothing spent this day',
                      style: TextStyle(color: Colors.white38)),
                )
              else
                for (final t in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        iconFor(_catById[t.categoryId]?.iconKey ?? 'other'),
                        color:
                            Color(_catById[t.categoryId]?.colorValue ?? 0xFF64748B)),
                    title: Text(_catById[t.categoryId]?.name ?? 'Uncategorized'),
                    subtitle: t.note == null ? null : Text(t.note!),
                    trailing: Text(Money.format(t.amountMinor),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
            ],
          ),
        ),
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

class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.byCategory,
    required this.catById,
    required this.selected,
    required this.onSelect,
  });

  final Map<int, int> byCategory;
  final Map<int, Category> catById;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
              child: Text('No spending this month',
                  style: TextStyle(color: Colors.white54))),
        ),
      );
    }

    Color colorOf(int id) => Color(catById[id]?.colorValue ?? 0xFF64748B);
    String nameOf(int id) => catById[id]?.name ?? 'Uncategorized';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 54,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, resp) {
                          if (!event.isInterestedForInteractions ||
                              resp?.touchedSection == null) {
                            return;
                          }
                          final idx =
                              resp!.touchedSection!.touchedSectionIndex;
                          if (idx >= 0 && idx < entries.length) {
                            onSelect(entries[idx].key);
                          }
                        },
                      ),
                      sections: [
                        for (final e in entries)
                          PieChartSectionData(
                            value: e.value.toDouble(),
                            color: colorOf(e.key),
                            radius: selected == e.key ? 30 : 22,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected == null
                            ? 'Total'
                            : nameOf(selected!),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        Money.format(
                            selected == null ? total : byCategory[selected]!),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      if (selected != null)
                        Text(
                          '${((byCategory[selected]! / total) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final e in entries.take(8))
                  InkWell(
                    onTap: () =>
                        onSelect(selected == e.key ? null : e.key),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: colorOf(e.key),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(nameOf(e.key),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected == e.key
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriversCard extends StatelessWidget {
  const _DriversCard({required this.monthKey});
  final String monthKey;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BudgetLine>>(
      stream: db.watchBudgetLines(monthKey),
      builder: (context, snap) {
        final over = (snap.data ?? const [])
            .where((l) => l.isOver)
            .toList()
          ..sort((a, b) => (b.spentMinor - b.availableMinor)
              .compareTo(a.spentMinor - a.availableMinor));
        if (over.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: MunshiTheme.negative, size: 20),
                    SizedBox(width: 8),
                    Text('Top overspend drivers',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final l in over.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(iconFor(l.category.iconKey),
                            size: 18, color: Color(l.category.colorValue)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l.category.name)),
                        Text('over ${Money.format(-l.remainingMinor)}',
                            style: const TextStyle(
                                color: MunshiTheme.negative,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.byMonth});
  final Map<String, int> byMonth;

  @override
  Widget build(BuildContext context) {
    final keys = byMonth.keys.toList();
    final values = keys.map((k) => byMonth[k]! / 100).toList();
    final maxV = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxV * 1.2,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= keys.length) return const SizedBox();
                      final parts = keys[i].split('-');
                      const months = [
                        'J','F','M','A','M','J','J','A','S','O','N','D'
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(months[int.parse(parts[1]) - 1],
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: values[i],
                      width: 18,
                      color: i == values.length - 1
                          ? MunshiTheme.accent
                          : MunshiTheme.accentDeep,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdayCard extends StatelessWidget {
  const _WeekdayCard({required this.byWeekday});
  final List<int> byWeekday;

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxV = byWeekday.isEmpty
        ? 1
        : byWeekday.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                        width: 36,
                        child: Text(labels[i],
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: byWeekday[i] / maxV,
                          minHeight: 10,
                          backgroundColor: Colors.white12,
                          color: MunshiTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Text(Money.format(byWeekday[i]),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
