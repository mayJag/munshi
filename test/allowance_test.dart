// Unit tests for the daily-allowance math (spread vs savings modes).

import 'package:flutter_test/flutter_test.dart';
import 'package:munshi/data/app_database.dart';
import 'package:munshi/features/dashboard/allowance.dart';
import 'package:munshi/services/settings_service.dart';

void main() {
  // April 2026 has 30 days; pretend "now" is the 10th.
  final now = DateTime(2026, 4, 10, 12);

  SpendSummary summary(int budget, int month, int today) => SpendSummary(
        budgetAllocatedMinor: budget,
        spentMonthMinor: month,
        spentTodayMinor: today,
      );

  group('Allowance.spread', () {
    test('splits remaining budget over days left including today', () {
      // ₹300 budget, ₹90 spent before today. Remaining ₹210 over 21 days = ₹10.
      final a = Allowance.compute(
        summary: summary(30000, 9000, 0),
        mode: LeftoverMode.spread,
        now: now,
      );
      expect(a.todayAllowanceMinor, 1000);
      expect(a.canSpendTodayMinor, 1000);
      expect(a.daysLeftInclusive, 21);
    });

    test('underspending prior days raises today\'s allowance', () {
      // Nothing spent yet: ₹300 over 21 days = ₹14.28 -> floored ₹14.
      final a = Allowance.compute(
        summary: summary(30000, 0, 0),
        mode: LeftoverMode.spread,
        now: now,
      );
      expect(a.todayAllowanceMinor, 1428);
    });
  });

  group('Allowance.savings', () {
    test('fixed daily slice; leftover accrues to savings', () {
      // baseline ₹300/30 = ₹10/day. 9 days elapsed, ₹90 spent -> ₹0 saved.
      final a = Allowance.compute(
        summary: summary(30000, 9000, 0),
        mode: LeftoverMode.savings,
        now: now,
      );
      expect(a.perDayBaselineMinor, 1000);
      expect(a.savedMinor, 0);
      expect(a.canSpendTodayMinor, 1000);
    });

    test('spending less than baseline builds savings', () {
      // 9 days elapsed at ₹10 baseline = ₹90 expected; only ₹40 spent -> ₹50 saved.
      final a = Allowance.compute(
        summary: summary(30000, 4000, 0),
        mode: LeftoverMode.savings,
        now: now,
      );
      expect(a.savedMinor, 5000);
    });
  });

  test('REGRESSION: fully over budget must not crash (clamp bug)', () {
    // ₹300 budget but ₹400 already spent before today -> used to throw
    // ArgumentError via clamp(0, negative). Must return 0 allowance.
    final a = Allowance.compute(
      summary: summary(30000, 40000, 0),
      mode: LeftoverMode.spread,
      now: now,
    );
    expect(a.todayAllowanceMinor, 0);
    expect(a.canSpendTodayMinor, 0);
  });

  test('no budget -> no allowance', () {
    final a = Allowance.compute(
      summary: summary(0, 0, 0),
      mode: LeftoverMode.spread,
      now: now,
    );
    expect(a.hasBudget, false);
    expect(a.todayAllowanceMinor, 0);
  });
}
