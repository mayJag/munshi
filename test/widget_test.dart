// Unit tests for money conversion/formatting (the core of financial correctness).

import 'package:flutter_test/flutter_test.dart';
import 'package:munshi/shared/money.dart';

void main() {
  group('Money', () {
    test('parses rupees to integer minor units (paise)', () {
      expect(Money.toMinor('1234.5'), 123450);
      expect(Money.toMinor('0'), 0);
      expect(Money.toMinor(''), 0);
      expect(Money.toMinor('99.99'), 9999);
    });

    test('formats minor units as whole rupees (en_IN grouping)', () {
      expect(Money.format(123400), '₹1,234');
      expect(Money.format(0), '₹0');
      expect(Money.format(10000000), '₹1,00,000');
    });

    test('paise-precision formatting keeps two decimals', () {
      expect(Money.formatPaise(123450), '₹1,234.50');
    });
  });
}
