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
    required this.nextDaysAllowanceMinor,
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

  /// Recalculated daily allowance for the days AFTER today — what today's
  /// spending leaves you for the rest of the month. In spread mode this is
  /// (budget − spent so far) ÷ days after today, so overspending today lowers
  /// it and underspending raises it. In savings mode it's the fixed slice.
  final int nextDaysAllowanceMinor;

  final bool hasBudget;

  /// Days remaining after today (0 on the last day of the month).
  int get daysAfterToday =>
      daysLeftInclusive - 1 < 0 ? 0 : daysLeftInclusive - 1;

  /// True once today's spending has eaten into today's allowance.
  bool get overspentToday => canSpendTodayMinor < 0;

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

    final daysAfter = daysLeftIncl - 1;

    if (b <= 0) {
      return Allowance(
        mode: mode,
        todayAllowanceMinor: 0,
        canSpendTodayMinor: 0,
        savedMinor: 0,
        perDayBaselineMinor: 0,
        daysLeftInclusive: daysLeftIncl,
        nextDaysAllowanceMinor: 0,
        hasBudget: false,
      );
    }

    if (mode == LeftoverMode.spread) {
      final remainingForToday = b - spentBeforeToday;
      // If the whole month's budget is already gone, today's allowance is 0
      // (clamp with a negative upper bound would throw).
      final todayAllowance = remainingForToday <= 0
          ? 0
          : (remainingForToday / daysLeftIncl).floor();
      // Recalculated allowance for the days after today: whatever's left of the
      // budget once today's actual spending is counted, spread over the days
      // that remain. Overspending today drops it; underspending lifts it.
      final remainingAfterToday = b - summary.spentMonthMinor;
      final nextDays = daysAfter <= 0
          ? (remainingAfterToday <= 0 ? 0 : remainingAfterToday)
          : (remainingAfterToday <= 0
              ? 0
              : (remainingAfterToday / daysAfter).floor());
      return Allowance(
        mode: mode,
        todayAllowanceMinor: todayAllowance,
        canSpendTodayMinor: todayAllowance - summary.spentTodayMinor,
        savedMinor: 0,
        perDayBaselineMinor: (b / daysInMonth).floor(),
        daysLeftInclusive: daysLeftIncl,
        nextDaysAllowanceMinor: nextDays,
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
      // Savings mode keeps a fixed daily slice regardless of today's spend.
      nextDaysAllowanceMinor: baseline,
      hasBudget: true,
    );
  }
}
