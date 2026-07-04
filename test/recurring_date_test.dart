// Regression tests for recurring due-date advancement (month-end drift bug).

import 'package:flutter_test/flutter_test.dart';
import 'package:munshi/data/app_database.dart';

void main() {
  group('AppDatabase.advanceDue monthly', () {
    test('Jan 31 -> Feb 28 (not Mar 3)', () {
      final next = AppDatabase.advanceDue(DateTime(2026, 1, 31), Frequency.monthly);
      expect(next, DateTime(2026, 2, 28));
    });

    test('leap year: Jan 31 2028 -> Feb 29', () {
      final next = AppDatabase.advanceDue(DateTime(2028, 1, 31), Frequency.monthly);
      expect(next, DateTime(2028, 2, 29));
    });

    test('Mar 31 -> Apr 30', () {
      final next = AppDatabase.advanceDue(DateTime(2026, 3, 31), Frequency.monthly);
      expect(next, DateTime(2026, 4, 30));
    });

    test('normal mid-month day unchanged', () {
      final next = AppDatabase.advanceDue(DateTime(2026, 5, 15), Frequency.monthly);
      expect(next, DateTime(2026, 6, 15));
    });

    test('December rolls into January next year', () {
      final next = AppDatabase.advanceDue(DateTime(2026, 12, 31), Frequency.monthly);
      expect(next, DateTime(2027, 1, 31));
    });
  });

  test('weekly and daily advance by exact interval', () {
    expect(AppDatabase.advanceDue(DateTime(2026, 7, 4), Frequency.weekly),
        DateTime(2026, 7, 11));
    expect(AppDatabase.advanceDue(DateTime(2026, 7, 4), Frequency.daily),
        DateTime(2026, 7, 5));
  });
}
