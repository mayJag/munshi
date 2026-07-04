// Verifies the full 3-sheet workbook (Transactions, Categories w/ pie,
// Accounts w/ bar) builds and writes a sample file for manual inspection.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munshi/data/app_database.dart';
import 'package:munshi/features/export/excel_exporter.dart';

void main() {
  test('builds a full 3-sheet workbook', () {
    final now = DateTime(2026, 7, 4, 10);
    final cat = Category(
      id: 1,
      name: 'Food',
      parentId: null,
      iconKey: 'food',
      colorValue: 0xFFF97316,
      kind: TxType.expense,
      isCustom: false,
      sortOrder: 0,
    );
    final acct = Account(
      id: 1,
      name: 'Cash',
      type: AccountType.cash,
      openingBalanceMinor: 500000,
      iconKey: 'cash',
      colorValue: 0xFF0D9488,
      isArchived: false,
    );
    TxRow tx(int id, int amt) => TxRow(
          id: id,
          occurredAt: now,
          amountMinor: amt,
          type: TxType.expense,
          categoryId: 1,
          accountId: 1,
          transferToAccountId: null,
          recurringTemplateId: null,
          note: 'lunch',
          createdAt: now,
        );

    final bytes = buildFullReport(
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 31),
      txns: [tx(1, 8200), tx(2, 3100)],
      catById: {1: cat},
      acctById: {1: acct},
      balances: [AccountBalance(account: acct, balanceMinor: 488700)],
    );

    expect(bytes, isNotEmpty);
    expect(bytes[0], 0x50); // PK zip magic
    expect(bytes[1], 0x4B);

    final file = File('${Directory.systemTemp.path}/munshi_full_export.xlsx');
    file.writeAsBytesSync(bytes, flush: true);
  });
}
