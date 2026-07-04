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

@DriftDatabase(tables: [Accounts, Categories, Transactions])
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'munshi.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
