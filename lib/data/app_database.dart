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
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(DateTime.now)();
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

@DriftDatabase(tables: [Accounts, Categories, Transactions, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
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
  Stream<SpendSummary> watchSpendSummary(String monthKey) {
    final start = monthStart(monthKey);
    final end = _monthEnd(monthKey);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return select(budgets).watch().asyncExpand((budgetRows) {
      return select(transactions).watch().map((txRows) {
        final allocated = budgetRows
            .where((b) => b.monthKey == monthKey)
            .fold<int>(0, (s, b) => s + b.allocatedMinor);
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'munshi.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
