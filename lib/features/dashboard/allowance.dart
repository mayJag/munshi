import '../../data/app_database.dart';
import '../../services/settings_service.dart';

/// Turns a monthly budget into a daily spendable number.
///
/// Two behaviours (per [LeftoverMode]):
/// - [LeftoverMode.spread]: unspent money flows forward. Today's allowance =
///   (total budget − spent before today) ÷ days left including today. Underspend
///   yesterday → more today.
/// - [LeftoverMode.savings]: each day gets a fixed slice (budget ÷ days in
///   month). Unspent slices pile up in [savedMinor] instead of raising other
///   days.
class Allowance {
  Allowance({
    required this.mode,
    required this.todayAllowanceMinor,
    required this.canSpendTodayMinor,
    required this.savedMinor,
    required this.perDayBaselineMinor,
    required this.daysLeftInclusive,
    required this.hasBudget,
  });

  final LeftoverMode mode;

  /// Total money assigned to today.
  final int todayAllowanceMinor;

  /// Money still spendable today (allowance − already spent today). May be < 0.
  final int canSpendTodayMinor;

  /// Savings accrued so far this month (savings mode only).
  final int savedMinor;

  /// Fixed daily slice (savings mode) or the even split (informational).
  final int perDayBaselineMinor;

  final int daysLeftInclusive;
  final bool hasBudget;

  static Allowance compute({
    required SpendSummary summary,
    required LeftoverMode mode,
    required DateTime now,
  }) {
    final b = summary.budgetAllocatedMinor;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final day = now.day;
    final daysLeftIncl = daysInMonth - day + 1;
    final spentBeforeToday = summary.spentMonthMinor - summary.spentTodayMinor;

    if (b <= 0) {
      return Allowance(
        mode: mode,
        todayAllowanceMinor: 0,
        canSpendTodayMinor: 0,
        savedMinor: 0,
        perDayBaselineMinor: 0,
        daysLeftInclusive: daysLeftIncl,
        hasBudget: false,
      );
    }

    if (mode == LeftoverMode.spread) {
      final remainingForToday = b - spentBeforeToday;
      final todayAllowance =
          (remainingForToday / daysLeftIncl).floor().clamp(0, remainingForToday);
      return Allowance(
        mode: mode,
        todayAllowanceMinor: todayAllowance,
        canSpendTodayMinor: todayAllowance - summary.spentTodayMinor,
        savedMinor: 0,
        perDayBaselineMinor: (b / daysInMonth).floor(),
        daysLeftInclusive: daysLeftIncl,
        hasBudget: true,
      );
    }

    // Savings mode: fixed daily slice, leftover accrues.
    final baseline = (b / daysInMonth).floor();
    final expectedByYesterday = baseline * (day - 1);
    final saved =
        (expectedByYesterday - spentBeforeToday).clamp(0, expectedByYesterday);
    return Allowance(
      mode: mode,
      todayAllowanceMinor: baseline,
      canSpendTodayMinor: baseline - summary.spentTodayMinor,
      savedMinor: saved,
      perDayBaselineMinor: baseline,
      daysLeftInclusive: daysLeftIncl,
      hasBudget: true,
    );
  }
}
