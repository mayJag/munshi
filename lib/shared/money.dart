import 'package:intl/intl.dart';

/// All money is stored as integer minor units (paise). Display layer formats ₹.
class Money {
  Money._();

  static final NumberFormat _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static final NumberFormat _fmtPaise =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  /// Whole-rupee display, e.g. 123450 -> "₹1,234".
  static String format(int minor) => _fmt.format(minor / 100);

  /// Paise-precision display, e.g. 123450 -> "₹1,234.50".
  static String formatPaise(int minor) => _fmtPaise.format(minor / 100);

  /// Parse a user-typed rupee string ("1234.5") to minor units (123450).
  static int toMinor(String rupees) {
    final v = double.tryParse(rupees.trim()) ?? 0;
    return (v * 100).round();
  }

  static final DateFormat _dateFmt = DateFormat('d MMM yyyy');

  /// e.g. "5 Jul 2026".
  static String dateLabel(DateTime d) => _dateFmt.format(d);

  /// Day-group heading: "Today" / "Yesterday" / "5 Jul 2026".
  static String dayHeading(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return _dateFmt.format(d);
  }
}
