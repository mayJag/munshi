import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../data/db.dart';
import '../features/dashboard/allowance.dart';
import '../shared/money.dart';
import 'settings_service.dart';

/// Pushes "safe to spend today" data to the Android home-screen widget.
///
/// Safe to call anywhere — it no-ops off Android and never throws.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _androidWidget = 'MunshiWidgetProvider';

  Future<void> refresh() async {
    if (!Platform.isAndroid) return;
    try {
      final monthKey = Money.monthKey(DateTime.now());
      final summary = await db.watchSpendSummary(monthKey).first;

      String label;
      String amount;
      String sub;
      if (summary.budgetAllocatedMinor <= 0) {
        label = 'This month';
        amount = Money.format(summary.spentMonthMinor);
        sub = 'spent · set a budget for a daily number';
      } else {
        final a = Allowance.compute(
          summary: summary,
          mode: SettingsService.instance.leftoverMode.value,
          now: DateTime.now(),
        );
        label = a.canSpendTodayMinor < 0
            ? 'Over budget today'
            : 'Safe to spend today';
        amount = Money.format(a.canSpendTodayMinor);
        final remaining = summary.budgetAllocatedMinor - summary.spentMonthMinor;
        sub = '${Money.format(remaining)} left this month';
      }

      await HomeWidget.saveWidgetData<String>('widget_label', label);
      await HomeWidget.saveWidgetData<String>('spendable_today', amount);
      await HomeWidget.saveWidgetData<String>('widget_sub', sub);
      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        qualifiedAndroidName: 'com.jagga.munshi.$_androidWidget',
      );
    } catch (_) {/* widget not added / plugin unavailable — ignore */}
  }
}
