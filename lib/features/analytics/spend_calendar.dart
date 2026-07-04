import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/money.dart';

/// A month calendar heat-grid: each day cell is tinted by how much was spent,
/// with the amount shown. Tapping a day calls [onTapDay].
class SpendCalendar extends StatelessWidget {
  const SpendCalendar({
    super.key,
    required this.month,
    required this.spentByDay,
    required this.onTapDay,
  });

  final DateTime month; // any day in the target month
  final Map<int, int> spentByDay; // day-of-month -> minor units
  final void Function(int day) onTapDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Dart weekday: Mon=1..Sun=7. Grid starts Monday.
    final leadingBlanks = first.weekday - 1;
    final maxSpend =
        spentByDay.values.isEmpty ? 0 : spentByDay.values.reduce((a, b) => a > b ? a : b);

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final spent = spentByDay[day] ?? 0;
      final intensity = maxSpend <= 0 ? 0.0 : (spent / maxSpend).clamp(0.0, 1.0);
      cells.add(_DayCell(
        day: day,
        spentMinor: spent,
        intensity: intensity,
        onTap: () => onTapDay(day),
      ));
    }

    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                for (final w in weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: cells,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.spentMinor,
    required this.intensity,
    required this.onTap,
  });

  final int day;
  final int spentMinor;
  final double intensity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = spentMinor <= 0
        ? MunshiTheme.surfaceHigh
        : Color.lerp(MunshiTheme.accentDeep.withValues(alpha: 0.25),
            MunshiTheme.accent, intensity)!;
    final textColor = intensity > 0.55 ? const Color(0xFF04120F) : Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            if (spentMinor > 0)
              Text(_short(spentMinor),
                  style: TextStyle(color: textColor, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  String _short(int minor) {
    final r = minor / 100;
    if (r >= 1000) return '${(r / 1000).toStringAsFixed(r >= 10000 ? 0 : 1)}k';
    return Money.format(minor).replaceAll('₹', '');
  }
}
