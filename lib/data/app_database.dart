import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Kind of an account. Balance is always computed (opening + txns), never stored.
enum AccountType { cash, bank, card, wallet }

/// Transaction direction. Transfers move money between accounts and are
/// excluded from category/spend aggregates.
enum TxType { expense, income, transfer }

/// How often a recurring template repeats.
enum Frequency { daily, weekly, monthly }

/// Reminder scheduling style.
enum ReminderMode { dailyAt, hourly }

@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get type => textEnum<AccountType>()();
  IntColumn get openingBalanceMinor =>
      integer().withDefault(const Constant(0))();
  TextColumn get iconKey => text().withDefault(const Constant('cash'))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF0D9488))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get parentId => integer().nullable()();
  TextColumn get iconKey => text().withDefault(const Constant('other'))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF64748B))();
  // Which side this category is used for.
  TextColumn get kind =>
      textEnum<TxType>().withDefault(const Constant('expense'))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('TxRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get amountMinor => integer()();
  TextColumn get type => textEnum<TxType>()();
  // FK links (enforced in app logic; joined manually for lists).
  IntColumn get categoryId => integer().nullable()();
  IntColumn get accountId => integer()();
  IntColumn get transferToAccountId => integer().nullable()();
  IntColumn get recurringTemplateId => integer().nullable()();
  TextColumn get note => text().nullable()();
  // Absolute file path to an attached receipt image, if any.
  TextColumn get receiptPath => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(DateTime.now)();
}

/// A savings goal the user is putting money aside for (holiday, phone, fund).
@DataClassName('SavingsGoal')
class SavingsGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get targetMinor => integer()();
  IntColumn get savedMinor => integer().withDefault(const Constant(0))();
  TextColumn get iconKey => text().withDefault(const Constant('savings'))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF2DD4BF))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// A single total-spend cap for an entire month, independent of category limits.
@DataClassName('MonthlyBudget')
class MonthlyBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get monthKey => text().withLength(min: 7, max: 7)();
  IntColumn get totalMinor => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [{monthKey}];
}

@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  // "YYYY-MM", e.g. "2026-07".
  TextColumn get monthKey => text().withLength(min: 7, max: 7)();
  IntColumn get categoryId => integer()();
  IntColumn get allocatedMinor => integer()();
  BoolColumn get rolloverEnabled =>
      boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {monthKey, categoryId},
      ];
}

@DataClassName('RecurringTemplate')
class RecurringTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get amountMinor => integer()();
  TextColumn get type =>
      textEnum<TxType>().withDefault(const Constant('expense'))();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get accountId => integer()();
  TextColumn get frequency =>
      textEnum<Frequency>().withDefault(const Constant('monthly'))();
  DateTimeColumn get nextDueDate => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

@DataClassName('Reminder')
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get message =>
      text().withDefault(const Constant('Log your spending'))();
  TextColumn get mode =>
      textEnum<ReminderMode>().withDefault(const Constant('dailyAt'))();
  IntColumn get hour => integer().withDefault(const Constant(21))();
  IntColumn get minute => integer().withDefault(const Constant(0))();
  IntColumn get intervalHours => integer().withDefault(const Constant(3))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// A transaction joined with its (optional) category and account, for lists.
class TxWithRefs {
  TxWithRefs({required this.tx, this.category, this.account, this.toAccount});
  final TxRow tx;
  final Category? category;
  final Account? account;
  final Account? toAccount;
}

/// Computed balance for an account.
class AccountBalance {
  AccountBalance({required this.account, required this.balanceMinor});
  final Account account;
  final int balanceMinor;
}

/// One category's budget picture for a month: allocation, actual spend, and
/// any rollover carried in from the previous month.
class BudgetLine {
  BudgetLine({
    required this.category,
    required this.allocatedMinor,
    required this.spentMinor,
    required this.rolloverInMinor,
    required this.rolloverEnabled,
    this.budgetId,
  });

  final Category category;
  final int allocatedMinor;
  final int spentMinor;
  final int rolloverInMinor;
  final bool rolloverEnabled;
  final int? budgetId;

  /// Total available = this month's allocation + carried-over surplus.
  int get availableMinor => allocatedMinor + rolloverInMinor;
  int get remainingMinor => availableMinor - spentMinor;
  bool get hasBudget => allocatedMinor > 0;
  double get progress =>
      availableMinor <= 0 ? 0 : (spentMinor / availableMinor).clamp(0, 1);
  bool get isOver => spentMinor > availableMinor && availableMinor > 0;
}

/// Rich month summary powering the "Wrapped" report.
class MonthWrapped {
  MonthWrapped({
    required this.monthKey,
    required this.spentMinor,
    required this.incomeMinor,
    required this.prevSpentMinor,
    required this.txnCount,
    required this.dailyAverageMinor,
    required this.topCategory,
    required this.topCategoryMinor,
    required this.biggestExpense,
    required this.biggestExpenseCategory,
    required this.busiestDayOfMonth,
    required this.busiestDayMinor,
    required this.topWeekday,
  });

  final String monthKey;
  final int spentMinor;
  final int incomeMinor;
  final int prevSpentMinor;
  final int txnCount;
  final int dailyAverageMinor;
  final Category? topCategory;
  final int topCategoryMinor;
  final TxRow? biggestExpense;
  final Category? biggestExpenseCategory;
  final int? busiestDayOfMonth;
  final int busiestDayMinor;
  final int? topWeekday; // 1=Mon .. 7=Sun

  bool get isEmpty => txnCount == 0;

  /// Percentage change vs last month (+ = spent more). null if no prior data.
  double? get momChange {
    if (prevSpentMinor == 0) return null;
    return (spentMinor - prevSpentMinor) / prevSpentMinor * 100;
  }
}

/// A past transaction title with the category it was last saved under.
class TitleSuggestion {
  TitleSuggestion({required this.title, this.categoryId});
  final String title;
  final int? categoryId;
}

/// Month spend snapshot used by the daily-allowance calculation.
class SpendSummary {
  SpendSummary({
    required this.budgetAllocatedMinor,
    required this.spentMonthMinor,
    required this.spentTodayMinor,
  });
  final int budgetAllocatedMinor;
  final int spentMonthMinor;
  final int spentTodayMinor;
}

@DriftDatabase(tables: [
  Accounts,
  Categories,
  Transactions,
  MonthlyBudgets,
  Budgets,
  RecurringTemplates,
  Reminders,
  SavingsGoals,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(recurringTemplates);
            await m.createTable(reminders);
            await m.addColumn(
                transactions, transactions.recurringTemplateId);
          }
          if (from < 3) {
            await m.createTable(monthlyBudgets);
          }
          if (from < 4) {
            await m.addColumn(transactions, transactions.receiptPath);
            await m.createTable(savingsGoals);
          }
        },
      );

  // ---- Seed -------------------------------------------------------------

  Future<void> _seed() async {
    await batch((b) {
      b.insert(
        accounts,
        AccountsCompanion.insert(
          name: 'Cash',
          type: AccountType.cash,
          iconKey: const Value('cash'),
          colorValue: const Value(0xFF0D9488),
        ),
      );
      b.insertAll(categories, _defaultCategories());
    });
  }

  List<CategoriesCompanion> _defaultCategories() {
    const expense = [
      ('Food', 'food', 0xFFF97316),
      ('Groceries', 'groceries', 0xFF22C55E),
      ('Transport', 'transport', 0xFF3B82F6),
      ('Shopping', 'shopping', 0xFFEC4899),
      ('Bills', 'bills', 0xFFEAB308),
      ('Rent', 'rent', 0xFF8B5CF6),
      ('Health', 'health', 0xFFEF4444),
      ('Fun', 'fun', 0xFF14B8A6),
      ('Education', 'education', 0xFF6366F1),
      ('Travel', 'travel', 0xFF06B6D4),
      ('Gifts', 'gifts', 0xFFF43F5E),
      ('Other', 'other', 0xFF64748B),
    ];
    const income = [
      ('Salary', 'salary', 0xFF16A34A),
      ('Business', 'business', 0xFF0D9488),
      ('Interest', 'interest', 0xFF65A30D),
      ('Other', 'other', 0xFF64748B),
    ];
    var order = 0;
    final rows = <CategoriesCompanion>[];
    for (final (name, icon, color) in expense) {
      rows.add(CategoriesCompanion.insert(
        name: name,
        iconKey: Value(icon),
        colorValue: Value(color),
        kind: const Value(TxType.expense),
        sortOrder: Value(order++),
      ));
    }
    for (final (name, icon, color) in income) {
      rows.add(CategoriesCompanion.insert(
        name: name,
        iconKey: Value(icon),
        colorValue: Value(color),
        kind: const Value(TxType.income),
        sortOrder: Value(order++),
      ));
    }
    return rows;
  }

  // ---- Categories -------------------------------------------------------

  Stream<List<Category>> watchCategories(TxType kind) {
    return (select(categories)
          ..where((c) => c.kind.equalsValue(kind))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .watch();
  }

  Future<List<Category>> allCategories() => select(categories).get();

  Future<int> upsertCategory(CategoriesCompanion c) =>
      into(categories).insertOnConflictUpdate(c);

  // ---- Accounts ---------------------------------------------------------

  Stream<List<Account>> watchAccounts({bool includeArchived = false}) {
    final q = select(accounts);
    if (!includeArchived) {
      q.where((a) => a.isArchived.equals(false));
    }
    q.orderBy([(a) => OrderingTerm(expression: a.id)]);
    return q.watch();
  }

  Future<List<Account>> activeAccounts() =>
      (select(accounts)..where((a) => a.isArchived.equals(false))).get();

  Future<int> insertAccount(AccountsCompanion a) => into(accounts).insert(a);

  Future<bool> updateAccount(Account a) => update(accounts).replace(a);

  Future<void> setAccountArchived(int id, bool archived) {
    return (update(accounts)..where((a) => a.id.equals(id)))
        .write(AccountsCompanion(isArchived: Value(archived)));
  }

  /// Balance for one account = opening + income + transfers-in − expense −
  /// transfers-out. Computed live, never stored.
  Stream<List<AccountBalance>> watchAccountBalances() {
    return watchAccounts().asyncExpand((accts) {
      return select(transactions).watch().map((txns) {
        return accts.map((a) {
          var bal = a.openingBalanceMinor;
          for (final t in txns) {
            if (t.accountId == a.id) {
              switch (t.type) {
                case TxType.income:
                  bal += t.amountMinor;
                case TxType.expense:
                case TxType.transfer:
                  bal -= t.amountMinor;
              }
            }
            if (t.type == TxType.transfer && t.transferToAccountId == a.id) {
              bal += t.amountMinor;
            }
          }
          return AccountBalance(account: a, balanceMinor: bal);
        }).toList();
      });
    });
  }

  // ---- Transactions -----------------------------------------------------

  Future<int> insertTx(TransactionsCompanion t) =>
      into(transactions).insert(t);

  Future<bool> updateTx(TxRow t) => update(transactions).replace(t);

  Future<void> deleteTx(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// All transactions, newest first, joined with category + accounts.
  Stream<List<TxWithRefs>> watchTransactions({int? limit}) {
    final q = select(transactions).join([
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
    ]);
    q.orderBy([OrderingTerm.desc(transactions.occurredAt)]);
    if (limit != null) q.limit(limit);

    return q.watch().asyncMap((rows) async {
      final acctById = {for (final a in await activeAccountsAll()) a.id: a};
      return rows.map((r) {
        final tx = r.readTable(transactions);
        return TxWithRefs(
          tx: tx,
          category: r.readTableOrNull(categories),
          account: r.readTableOrNull(accounts),
          toAccount: tx.transferToAccountId == null
              ? null
              : acctById[tx.transferToAccountId],
        );
      }).toList();
    });
  }

  Future<List<Account>> activeAccountsAll() => select(accounts).get();

  /// Sum of a [TxType] within [from, to). Transfers excluded from spend.
  Stream<int> watchTotal(TxType type, DateTime from, DateTime to) {
    final amount = transactions.amountMinor.sum();
    final q = selectOnly(transactions)
      ..addColumns([amount])
      ..where(transactions.type.equalsValue(type) &
          transactions.occurredAt.isBiggerOrEqualValue(from) &
          transactions.occurredAt.isSmallerThanValue(to));
    return q.watchSingle().map((r) => r.read(amount) ?? 0);
  }

  // ---- Title suggestions --------------------------------------------------

  /// Past transaction titles matching [prefix], newest first, with the
  /// category each was last saved under (Cashew-style title -> category
  /// memory). Empty prefix returns the most recent distinct titles.
  Future<List<TitleSuggestion>> titleSuggestions(String prefix,
      {int limit = 8}) async {
    final q = select(transactions)
      ..where((t) => t.note.isNotNull() & t.note.like('$prefix%'))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    final rows = await q.get();
    final seen = <String>{};
    final out = <TitleSuggestion>[];
    for (final t in rows) {
      final title = t.note!.trim();
      if (title.isEmpty) continue;
      final key = title.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(TitleSuggestion(title: title, categoryId: t.categoryId));
      if (out.length >= limit) break;
    }
    return out;
  }

  // ---- Monthly total budget ---------------------------------------------

  Stream<MonthlyBudget?> watchMonthlyBudget(String monthKey) {
    return (select(monthlyBudgets)..where((b) => b.monthKey.equals(monthKey)))
        .watchSingleOrNull();
  }

  Future<void> setMonthlyBudget(String monthKey, int totalMinor) {
    return into(monthlyBudgets).insert(
      MonthlyBudgetsCompanion.insert(monthKey: monthKey, totalMinor: totalMinor),
      onConflict: DoUpdate(
        (_) => MonthlyBudgetsCompanion(totalMinor: Value(totalMinor)),
        target: [monthlyBudgets.monthKey],
      ),
    );
  }

  Future<void> clearMonthlyBudget(String monthKey) {
    return (delete(monthlyBudgets)..where((b) => b.monthKey.equals(monthKey)))
        .go();
  }

  // ---- Budgets ----------------------------------------------------------

  static DateTime monthStart(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
  }

  static DateTime _monthEnd(String key) {
    final s = monthStart(key);
    return DateTime(s.year, s.month + 1, 1);
  }

  static String prevMonthKey(String key) {
    final s = monthStart(key);
    final p = DateTime(s.year, s.month - 1, 1);
    return '${p.year.toString().padLeft(4, '0')}-'
        '${p.month.toString().padLeft(2, '0')}';
  }

  /// Reactive budget-vs-actual lines for [monthKey], one per expense category,
  /// including rollover carried from the previous month when enabled.
  Stream<List<BudgetLine>> watchBudgetLines(String monthKey) {
    final prevKey = prevMonthKey(monthKey);
    final thisStart = monthStart(monthKey);
    final thisEnd = _monthEnd(monthKey);
    final prevStart = monthStart(prevKey);
    final prevEnd = thisStart;

    return select(budgets).watch().asyncExpand((budgetRows) {
      return select(transactions).watch().asyncMap((txRows) async {
        final cats = await allCategories();
        final expenseCats = cats
            .where((c) => c.kind == TxType.expense)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        int spentIn(int catId, DateTime from, DateTime to) => txRows
            .where((t) =>
                t.type == TxType.expense &&
                t.categoryId == catId &&
                !t.occurredAt.isBefore(from) &&
                t.occurredAt.isBefore(to))
            .fold(0, (s, t) => s + t.amountMinor);

        final thisB = {
          for (final b in budgetRows.where((b) => b.monthKey == monthKey))
            b.categoryId: b
        };
        final prevB = {
          for (final b in budgetRows.where((b) => b.monthKey == prevKey))
            b.categoryId: b
        };

        return expenseCats.map((c) {
          final b = thisB[c.id];
          final rollEnabled = b?.rolloverEnabled ?? false;
          var rolloverIn = 0;
          if (rollEnabled && prevB[c.id] != null) {
            final leftover =
                prevB[c.id]!.allocatedMinor - spentIn(c.id, prevStart, prevEnd);
            if (leftover > 0) rolloverIn = leftover;
          }
          return BudgetLine(
            category: c,
            allocatedMinor: b?.allocatedMinor ?? 0,
            spentMinor: spentIn(c.id, thisStart, thisEnd),
            rolloverInMinor: rolloverIn,
            rolloverEnabled: rollEnabled,
            budgetId: b?.id,
          );
        }).toList();
      });
    });
  }

  Future<void> upsertBudget({
    required String monthKey,
    required int categoryId,
    required int allocatedMinor,
    required bool rolloverEnabled,
  }) {
    return into(budgets).insert(
      BudgetsCompanion.insert(
        monthKey: monthKey,
        categoryId: categoryId,
        allocatedMinor: allocatedMinor,
        rolloverEnabled: Value(rolloverEnabled),
      ),
      onConflict: DoUpdate(
        (_) => BudgetsCompanion(
          allocatedMinor: Value(allocatedMinor),
          rolloverEnabled: Value(rolloverEnabled),
        ),
        target: [budgets.monthKey, budgets.categoryId],
      ),
    );
  }

  /// Raw transactions within [from, to), newest first, optionally by [type].
  Stream<List<TxRow>> watchTxInRange(DateTime from, DateTime to,
      {TxType? type}) {
    final q = select(transactions)
      ..where((t) =>
          t.occurredAt.isBiggerOrEqualValue(from) &
          t.occurredAt.isSmallerThanValue(to));
    if (type != null) {
      q.where((t) => t.type.equalsValue(type));
    }
    q.orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return q.watch();
  }

  /// Reactive month snapshot: total budget set, spend this month, spend today.
  /// If a monthly total budget is set it takes precedence over the sum of
  /// category budgets — so the daily-allowance maths uses the right ceiling.
  Stream<SpendSummary> watchSpendSummary(String monthKey) {
    final start = monthStart(monthKey);
    final end = _monthEnd(monthKey);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return select(monthlyBudgets).watch().asyncExpand((monthlyRows) {
      return select(budgets).watch().asyncExpand((budgetRows) {
        return select(transactions).watch().map((txRows) {
          final monthlyEntry =
              monthlyRows.where((b) => b.monthKey == monthKey).firstOrNull;
          final categoryTotal = budgetRows
              .where((b) => b.monthKey == monthKey)
              .fold<int>(0, (s, b) => s + b.allocatedMinor);
          final allocated = monthlyEntry?.totalMinor ?? categoryTotal;

          var spentMonth = 0;
          var spentToday = 0;
          for (final t in txRows) {
            if (t.type != TxType.expense) continue;
            if (!t.occurredAt.isBefore(start) && t.occurredAt.isBefore(end)) {
              spentMonth += t.amountMinor;
            }
            if (!t.occurredAt.isBefore(todayStart) &&
                t.occurredAt.isBefore(todayEnd)) {
              spentToday += t.amountMinor;
            }
          }
          return SpendSummary(
            budgetAllocatedMinor: allocated,
            spentMonthMinor: spentMonth,
            spentTodayMinor: spentToday,
          );
        });
      });
    });
  }

  Future<void> clearBudget(String monthKey, int categoryId) {
    return (delete(budgets)
          ..where((b) =>
              b.monthKey.equals(monthKey) & b.categoryId.equals(categoryId)))
        .go();
  }

  /// Apply a starter template: {categoryName: allocatedMinor} for [monthKey].
  Future<void> applyTemplate(
      String monthKey, Map<String, int> allocations) async {
    final cats = await allCategories();
    for (final entry in allocations.entries) {
      final cat = cats.firstWhere(
        (c) => c.kind == TxType.expense && c.name == entry.key,
        orElse: () => cats.first,
      );
      if (cat.name != entry.key) continue;
      await upsertBudget(
        monthKey: monthKey,
        categoryId: cat.id,
        allocatedMinor: entry.value,
        rolloverEnabled: false,
      );
    }
  }

  /// Remove every budget row for a month (reset).
  Future<void> clearMonthBudgets(String monthKey) {
    return (delete(budgets)..where((b) => b.monthKey.equals(monthKey))).go();
  }

  // ---- Categories (custom) ---------------------------------------------

  Stream<List<Category>> watchAllCategories() {
    return (select(categories)
          ..orderBy([
            (c) => OrderingTerm(expression: c.kind),
            (c) => OrderingTerm(expression: c.sortOrder),
          ]))
        .watch();
  }

  Future<int> insertCategory(CategoriesCompanion c) =>
      into(categories).insert(c);

  Future<bool> updateCategoryRow(Category c) =>
      update(categories).replace(c);

  /// Delete a category; its transactions are kept but become uncategorized.
  /// Recurring templates pointing at it also become uncategorized.
  Future<void> deleteCategory(int id) async {
    await (update(transactions)..where((t) => t.categoryId.equals(id)))
        .write(const TransactionsCompanion(categoryId: Value(null)));
    await (update(recurringTemplates)..where((r) => r.categoryId.equals(id)))
        .write(const RecurringTemplatesCompanion(categoryId: Value(null)));
    await (delete(budgets)..where((b) => b.categoryId.equals(id))).go();
    await (delete(categories)..where((c) => c.id.equals(id))).go();
  }

  // ---- Account delete (cascade) ----------------------------------------

  /// Permanently delete an account, every transaction into/out of it, and any
  /// recurring templates that would log into it.
  Future<void> deleteAccountCascade(int id) async {
    await (delete(transactions)
          ..where((t) =>
              t.accountId.equals(id) | t.transferToAccountId.equals(id)))
        .go();
    await (delete(recurringTemplates)..where((r) => r.accountId.equals(id)))
        .go();
    await (delete(accounts)..where((a) => a.id.equals(id))).go();
  }

  // ---- Recurring templates ---------------------------------------------

  Stream<List<RecurringTemplate>> watchRecurring() {
    return (select(recurringTemplates)
          ..orderBy([(r) => OrderingTerm(expression: r.nextDueDate)]))
        .watch();
  }

  Future<int> insertRecurring(RecurringTemplatesCompanion r) =>
      into(recurringTemplates).insert(r);

  Future<bool> updateRecurring(RecurringTemplate r) =>
      update(recurringTemplates).replace(r);

  Future<void> deleteRecurring(int id) =>
      (delete(recurringTemplates)..where((r) => r.id.equals(id))).go();

  static DateTime advanceDue(DateTime d, Frequency f) {
    switch (f) {
      case Frequency.daily:
        return d.add(const Duration(days: 1));
      case Frequency.weekly:
        return d.add(const Duration(days: 7));
      case Frequency.monthly:
        // Clamp to the target month's last day so Jan 31 -> Feb 28, not Mar 3.
        final lastDay = DateTime(d.year, d.month + 2, 0).day;
        final day = d.day > lastDay ? lastDay : d.day;
        return DateTime(d.year, d.month + 1, day, d.hour, d.minute);
    }
  }

  /// Log a recurring template as a real transaction now, then advance its due
  /// date by one interval.
  Future<void> logRecurringNow(RecurringTemplate t) async {
    await insertTx(TransactionsCompanion.insert(
      occurredAt: DateTime.now(),
      amountMinor: t.amountMinor,
      type: t.type,
      accountId: t.accountId,
      categoryId: Value(t.categoryId),
      note: Value(t.note),
      recurringTemplateId: Value(t.id),
    ));
    await updateRecurring(
        t.copyWith(nextDueDate: advanceDue(t.nextDueDate, t.frequency)));
  }

  // ---- Reminders --------------------------------------------------------

  Stream<List<Reminder>> watchReminders() =>
      (select(reminders)..orderBy([(r) => OrderingTerm(expression: r.hour)]))
          .watch();

  Future<List<Reminder>> activeReminders() =>
      (select(reminders)..where((r) => r.isActive.equals(true))).get();

  Future<int> insertReminder(RemindersCompanion r) =>
      into(reminders).insert(r);

  Future<bool> updateReminder(Reminder r) => update(reminders).replace(r);

  Future<void> deleteReminder(int id) =>
      (delete(reminders)..where((r) => r.id.equals(id))).go();

  // ---- Savings goals ----------------------------------------------------

  Stream<List<SavingsGoal>> watchSavingsGoals() {
    return (select(savingsGoals)
          ..where((g) => g.isArchived.equals(false))
          ..orderBy([(g) => OrderingTerm(expression: g.sortOrder)]))
        .watch();
  }

  Future<int> insertSavingsGoal(SavingsGoalsCompanion g) =>
      into(savingsGoals).insert(g);

  Future<bool> updateSavingsGoal(SavingsGoal g) =>
      update(savingsGoals).replace(g);

  Future<void> deleteSavingsGoal(int id) =>
      (delete(savingsGoals)..where((g) => g.id.equals(id))).go();

  /// Add (or, with a negative delta, withdraw) money from a goal, clamped to
  /// a non-negative saved total.
  Future<void> contributeToGoal(int id, int deltaMinor) async {
    final g =
        await (select(savingsGoals)..where((r) => r.id.equals(id))).getSingle();
    final next = (g.savedMinor + deltaMinor).clamp(0, 1 << 62);
    await (update(savingsGoals)..where((r) => r.id.equals(id)))
        .write(SavingsGoalsCompanion(savedMinor: Value(next)));
  }

  // ---- Subscriptions (derived from recurring templates) -----------------

  /// Active recurring expenses, treated as subscriptions/bills.
  Stream<List<RecurringTemplate>> watchSubscriptions() {
    return (select(recurringTemplates)
          ..where((r) =>
              r.isActive.equals(true) & r.type.equalsValue(TxType.expense))
          ..orderBy([(r) => OrderingTerm(expression: r.nextDueDate)]))
        .watch();
  }

  // ---- Search / filtered activity ---------------------------------------

  /// Filtered, joined transactions for the Activity search. [query] matches
  /// the note or the category name (case-insensitive). [types] limits by
  /// direction (empty = all).
  Stream<List<TxWithRefs>> watchTransactionsFiltered({
    String query = '',
    Set<TxType> types = const {},
  }) {
    final q = select(transactions).join([
      leftOuterJoin(
          categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
    ]);
    if (types.isNotEmpty) {
      q.where(transactions.type.isIn(types.map((t) => t.name).toList()));
    }
    q.orderBy([OrderingTerm.desc(transactions.occurredAt)]);

    return q.watch().asyncMap((rows) async {
      final acctById = {for (final a in await activeAccountsAll()) a.id: a};
      final term = query.trim().toLowerCase();
      final out = <TxWithRefs>[];
      for (final r in rows) {
        final tx = r.readTable(transactions);
        final cat = r.readTableOrNull(categories);
        if (term.isNotEmpty) {
          final note = (tx.note ?? '').toLowerCase();
          final catName = (cat?.name ?? '').toLowerCase();
          if (!note.contains(term) && !catName.contains(term)) continue;
        }
        out.add(TxWithRefs(
          tx: tx,
          category: cat,
          account: r.readTableOrNull(accounts),
          toAccount: tx.transferToAccountId == null
              ? null
              : acctById[tx.transferToAccountId],
        ));
      }
      return out;
    });
  }

  // ---- Month wrapped (one-shot aggregate) -------------------------------

  /// Compute a rich month summary for the "Wrapped" report.
  Future<MonthWrapped> monthWrapped(String monthKey) async {
    final start = monthStart(monthKey);
    final end = _monthEnd(monthKey);
    final prevKey = prevMonthKey(monthKey);
    final prevStart = monthStart(prevKey);
    final prevEnd = start;

    final txns = await (select(transactions)
          ..where((t) =>
              t.occurredAt.isBiggerOrEqualValue(prevStart) &
              t.occurredAt.isSmallerThanValue(end)))
        .get();
    final cats = {for (final c in await allCategories()) c.id: c};

    var spent = 0, income = 0, prevSpent = 0, txnCount = 0;
    TxRow? biggest;
    final byCategory = <int, int>{};
    final byDay = <int, int>{}; // day-of-month -> spend
    final byWeekday = <int, int>{}; // 1..7 -> spend

    for (final t in txns) {
      final inThis =
          !t.occurredAt.isBefore(start) && t.occurredAt.isBefore(end);
      final inPrev = !t.occurredAt.isBefore(prevStart) &&
          t.occurredAt.isBefore(prevEnd);
      if (t.type == TxType.expense) {
        if (inThis) {
          spent += t.amountMinor;
          txnCount++;
          if (biggest == null || t.amountMinor > biggest.amountMinor) {
            biggest = t;
          }
          if (t.categoryId != null) {
            byCategory[t.categoryId!] =
                (byCategory[t.categoryId!] ?? 0) + t.amountMinor;
          }
          byDay[t.occurredAt.day] =
              (byDay[t.occurredAt.day] ?? 0) + t.amountMinor;
          byWeekday[t.occurredAt.weekday] =
              (byWeekday[t.occurredAt.weekday] ?? 0) + t.amountMinor;
        } else if (inPrev) {
          prevSpent += t.amountMinor;
        }
      } else if (t.type == TxType.income && inThis) {
        income += t.amountMinor;
      }
    }

    int? topCatId;
    var topCatAmount = 0;
    byCategory.forEach((k, v) {
      if (v > topCatAmount) {
        topCatAmount = v;
        topCatId = k;
      }
    });

    int? busiestDay;
    var busiestAmount = 0;
    byDay.forEach((k, v) {
      if (v > busiestAmount) {
        busiestAmount = v;
        busiestDay = k;
      }
    });

    int? topWeekday;
    var topWeekdayAmount = 0;
    byWeekday.forEach((k, v) {
      if (v > topWeekdayAmount) {
        topWeekdayAmount = v;
        topWeekday = k;
      }
    });

    final daysElapsed = _daysElapsed(start, end);

    return MonthWrapped(
      monthKey: monthKey,
      spentMinor: spent,
      incomeMinor: income,
      prevSpentMinor: prevSpent,
      txnCount: txnCount,
      dailyAverageMinor: daysElapsed <= 0 ? 0 : spent ~/ daysElapsed,
      topCategory: topCatId == null ? null : cats[topCatId],
      topCategoryMinor: topCatAmount,
      biggestExpense: biggest,
      biggestExpenseCategory:
          biggest?.categoryId == null ? null : cats[biggest!.categoryId],
      busiestDayOfMonth: busiestDay,
      busiestDayMinor: busiestAmount,
      topWeekday: topWeekday,
    );
  }

  static int _daysElapsed(DateTime start, DateTime end) {
    final now = DateTime.now();
    // If the month is in the past, count all its days; if current, days so far.
    final effectiveEnd = now.isBefore(end) ? now : end;
    return effectiveEnd.difference(start).inDays.clamp(1, 400);
  }

  // ---- Backup / restore (JSON snapshot of all financial data) -----------

  Future<Map<String, dynamic>> exportSnapshot() async {
    return {
      'version': schemaVersion,
      'accounts':
          (await select(accounts).get()).map((e) => e.toJson()).toList(),
      'categories':
          (await select(categories).get()).map((e) => e.toJson()).toList(),
      'transactions':
          (await select(transactions).get()).map((e) => e.toJson()).toList(),
      'monthlyBudgets':
          (await select(monthlyBudgets).get()).map((e) => e.toJson()).toList(),
      'budgets':
          (await select(budgets).get()).map((e) => e.toJson()).toList(),
      'recurringTemplates': (await select(recurringTemplates).get())
          .map((e) => e.toJson())
          .toList(),
      'reminders':
          (await select(reminders).get()).map((e) => e.toJson()).toList(),
      'savingsGoals':
          (await select(savingsGoals).get()).map((e) => e.toJson()).toList(),
    };
  }

  /// Wipe everything and reload from a snapshot. Destructive — caller confirms.
  Future<void> restoreSnapshot(Map<String, dynamic> snap) async {
    List<Map<String, dynamic>> rows(String key) =>
        ((snap[key] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    await transaction(() async {
      await delete(transactions).go();
      await delete(budgets).go();
      await delete(monthlyBudgets).go();
      await delete(recurringTemplates).go();
      await delete(reminders).go();
      await delete(savingsGoals).go();
      await delete(categories).go();
      await delete(accounts).go();

      for (final r in rows('accounts')) {
        await into(accounts).insertOnConflictUpdate(Account.fromJson(r));
      }
      for (final r in rows('categories')) {
        await into(categories).insertOnConflictUpdate(Category.fromJson(r));
      }
      for (final r in rows('transactions')) {
        await into(transactions).insertOnConflictUpdate(TxRow.fromJson(r));
      }
      for (final r in rows('monthlyBudgets')) {
        await into(monthlyBudgets)
            .insertOnConflictUpdate(MonthlyBudget.fromJson(r));
      }
      for (final r in rows('budgets')) {
        await into(budgets).insertOnConflictUpdate(Budget.fromJson(r));
      }
      for (final r in rows('recurringTemplates')) {
        await into(recurringTemplates)
            .insertOnConflictUpdate(RecurringTemplate.fromJson(r));
      }
      for (final r in rows('reminders')) {
        await into(reminders).insertOnConflictUpdate(Reminder.fromJson(r));
      }
      for (final r in rows('savingsGoals')) {
        await into(savingsGoals)
            .insertOnConflictUpdate(SavingsGoal.fromJson(r));
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'munshi.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
