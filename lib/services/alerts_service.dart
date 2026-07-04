import '../data/app_database.dart';
import '../data/db.dart';
import '../shared/money.dart';
import 'notification_service.dart';

/// Fires local budget alerts when an expense pushes a category past 80% / 100%
/// of its monthly budget. De-dupes so each tier alerts at most once per
/// category per month (per app session).
class AlertsService {
  AlertsService._();
  static final AlertsService instance = AlertsService._();

  final Set<String> _fired = {};

  Future<void> checkAfterExpense(int? categoryId) async {
    if (categoryId == null) return;
    final monthKey = Money.monthKey(DateTime.now());
    final lines = await db.watchBudgetLines(monthKey).first;
    BudgetLine? line;
    for (final l in lines) {
      if (l.category.id == categoryId) {
        line = l;
        break;
      }
    }
    if (line == null || line.availableMinor <= 0) return;

    final pct = (line.spentMinor / line.availableMinor * 100).floor();
    final tier = pct >= 100 ? 100 : (pct >= 80 ? 80 : 0);
    if (tier == 0) return;

    final key = '$categoryId:$monthKey:$tier';
    if (_fired.contains(key)) return;
    _fired.add(key);
    await NotificationService.instance.showOverspendAlert(line.category.name, pct);
  }
}
