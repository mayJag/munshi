import 'dart:io';

import 'package:flutter/services.dart';

import '../data/db.dart';
import '../features/dashboard/allowance.dart';
import '../shared/money.dart';
import 'settings_service.dart';

/// Talks to the native Android home-screen widgets over a MethodChannel —
/// no third-party plugin involved. Safe to call anywhere: no-ops off Android
/// and never throws.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _channel = MethodChannel('com.jagga.munshi/widget');

  /// Recompute safe-to-spend and push it to the widget.
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
        final remaining =
            summary.budgetAllocatedMinor - summary.spentMonthMinor;
        sub = '${Money.format(remaining)} left this month';
      }

      await _channel.invokeMethod('updateWidget', {
        'label': label,
        'amount': amount,
        'sub': sub,
      });
    } catch (_) {/* widget not present / channel unavailable — ignore */}
  }

  /// URI the app was opened with from a widget tap ("munshiwidget://quickadd"),
  /// or null. The native side clears it after one read, so warm resumes can
  /// poll this safely.
  Future<Uri?> consumeLaunchUri() async {
    if (!Platform.isAndroid) return null;
    try {
      final s = await _channel.invokeMethod<String>('consumeLaunchUri');
      return s == null ? null : Uri.tryParse(s);
    } catch (_) {
      return null;
    }
  }
}
