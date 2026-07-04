import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:syncfusion_officechart/officechart.dart';

import '../../data/app_database.dart';
import '../../shared/money.dart';

/// A single category's spend, used to build the export summary + chart.
class CategorySpend {
  const CategorySpend(this.category, this.amount);
  final String category;
  final double amount;
}

/// Builds the full Munshi workbook for a date range: a Transactions log, a
/// Category summary (with pie chart), and an Accounts summary (with bar chart).
/// Returns the raw `.xlsx` bytes. Pure Dart — runs on-device and in tests.
List<int> buildFullReport({
  required DateTime from,
  required DateTime to,
  required List<TxRow> txns,
  required Map<int, Category> catById,
  required Map<int, Account> acctById,
  required List<AccountBalance> balances,
}) {
  final workbook = Workbook(3);
  _buildTransactionsSheet(
      workbook.worksheets[0], txns, catById, acctById, from, to);
  _buildCategorySheet(workbook.worksheets[1], txns, catById);
  _buildAccountsSheet(workbook.worksheets[2], balances);

  final bytes = workbook.saveAsStream();
  workbook.dispose();
  return bytes;
}

void _title(Worksheet sheet, String text) {
  final c = sheet.getRangeByName('A1');
  c.setText(text);
  c.cellStyle
    ..bold = true
    ..fontSize = 15
    ..fontColor = '#0D9488';
}

void _headerRow(Worksheet sheet, int row, List<String> headers) {
  for (var i = 0; i < headers.length; i++) {
    final cell = sheet.getRangeByIndex(row, i + 1);
    cell.setText(headers[i]);
    cell.cellStyle
      ..bold = true
      ..backColor = '#0D9488'
      ..fontColor = '#FFFFFF';
  }
}

void _buildTransactionsSheet(
  Worksheet sheet,
  List<TxRow> txns,
  Map<int, Category> catById,
  Map<int, Account> acctById,
  DateTime from,
  DateTime to,
) {
  sheet.name = 'Transactions';
  _title(sheet,
      'Transactions  ${Money.dateLabel(from)} – ${Money.dateLabel(to)}');
  _headerRow(sheet, 3, ['Date', 'Type', 'Category', 'Account', 'Note', 'Amount']);

  var row = 4;
  final sorted = [...txns]
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  for (final t in sorted) {
    sheet.getRangeByIndex(row, 1).setText(Money.dateLabel(t.occurredAt));
    sheet.getRangeByIndex(row, 2).setText(t.type.name);
    sheet.getRangeByIndex(row, 3).setText(t.type == TxType.transfer
        ? '—'
        : (catById[t.categoryId]?.name ?? 'Uncategorized'));
    sheet.getRangeByIndex(row, 4).setText(acctById[t.accountId]?.name ?? '?');
    sheet.getRangeByIndex(row, 5).setText(t.note ?? '');
    final amt = sheet.getRangeByIndex(row, 6);
    amt.setNumber(t.amountMinor / 100);
    amt.numberFormat = '₹#,##0';
    row++;
  }
  sheet.getRangeByName('A1:F$row').autoFitColumns();
}

void _buildCategorySheet(
  Worksheet sheet,
  List<TxRow> txns,
  Map<int, Category> catById,
) {
  sheet.name = 'Categories';
  _title(sheet, 'Spending by Category');
  _headerRow(sheet, 3, ['Category', 'Amount']);

  final totals = <String, double>{};
  for (final t in txns) {
    if (t.type != TxType.expense) continue;
    final name = catById[t.categoryId]?.name ?? 'Uncategorized';
    totals[name] = (totals[name] ?? 0) + t.amountMinor / 100;
  }
  final entries = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  var row = 4;
  for (final e in entries) {
    sheet.getRangeByIndex(row, 1).setText(e.key);
    final amt = sheet.getRangeByIndex(row, 2);
    amt.setNumber(e.value);
    amt.numberFormat = '₹#,##0';
    row++;
  }
  final lastRow = row - 1;
  sheet.getRangeByName('A1:B$row').autoFitColumns();

  if (entries.isNotEmpty) {
    final charts = ChartCollection(sheet);
    final chart = charts.add();
    chart.chartType = ExcelChartType.pie;
    chart.dataRange = sheet.getRangeByName('A3:B$lastRow');
    chart.isSeriesInRows = false;
    chart.chartTitle = 'Spending by Category';
    chart.hasLegend = true;
    chart.topRow = 2;
    chart.leftColumn = 4;
    chart.bottomRow = 22;
    chart.rightColumn = 13;
    sheet.charts = charts;
  }
}

void _buildAccountsSheet(Worksheet sheet, List<AccountBalance> balances) {
  sheet.name = 'Accounts';
  _title(sheet, 'Account Balances');
  _headerRow(sheet, 3, ['Account', 'Balance', 'Type']);

  var row = 4;
  for (final b in balances) {
    sheet.getRangeByIndex(row, 1).setText(b.account.name);
    final amt = sheet.getRangeByIndex(row, 2);
    amt.setNumber(b.balanceMinor / 100);
    amt.numberFormat = '₹#,##0';
    sheet.getRangeByIndex(row, 3).setText(b.account.type.name);
    row++;
  }
  final lastRow = row - 1;
  sheet.getRangeByName('A1:C$row').autoFitColumns();

  if (balances.isNotEmpty) {
    final charts = ChartCollection(sheet);
    final chart = charts.add();
    chart.chartType = ExcelChartType.column;
    chart.dataRange = sheet.getRangeByName('A3:B$lastRow');
    chart.isSeriesInRows = false;
    chart.chartTitle = 'Balances';
    chart.topRow = 2;
    chart.leftColumn = 5;
    chart.bottomRow = 20;
    chart.rightColumn = 13;
    sheet.charts = charts;
  }
}

/// Builds a styled `.xlsx` workbook with a native, editable embedded pie chart
/// summarising spend by category, and returns the raw bytes.
///
/// This is the Phase-0 proof for the hardest requirement (native charts in
/// Excel) and the foundation the Phase-5 3-sheet export builds on. Pure Dart —
/// no platform channels — so it runs in tests and on-device alike.
List<int> buildCategoryReport({
  required List<CategorySpend> spends,
  String currencySymbol = '₹', // ₹
  String title = 'Spending by Category',
}) {
  final workbook = Workbook();
  final sheet = workbook.worksheets[0];
  sheet.name = 'Summary';

  // Title row.
  final titleCell = sheet.getRangeByName('A1');
  titleCell.setText(title);
  titleCell.cellStyle
    ..bold = true
    ..fontSize = 16
    ..fontColor = '#0D9488';
  sheet.getRangeByName('A1:B1').merge();

  // Header row.
  final header = sheet.getRangeByName('A3:B3');
  header.setText('Category');
  sheet.getRangeByName('B3').setText('Amount');
  header.cellStyle
    ..bold = true
    ..backColor = '#0D9488'
    ..fontColor = '#FFFFFF';

  // Data rows.
  var row = 4;
  for (final s in spends) {
    sheet.getRangeByName('A$row').setText(s.category);
    final amt = sheet.getRangeByName('B$row');
    amt.setNumber(s.amount);
    amt.numberFormat = '$currencySymbol#,##0';
    row++;
  }
  final lastRow = row - 1;

  // Total row.
  final totalLabel = sheet.getRangeByName('A$row');
  totalLabel.setText('Total');
  totalLabel.cellStyle.bold = true;
  final totalCell = sheet.getRangeByName('B$row');
  totalCell.setFormula('=SUM(B4:B$lastRow)');
  totalCell.numberFormat = '$currencySymbol#,##0';
  totalCell.cellStyle.bold = true;

  sheet.getRangeByName('A1:B$row').autoFitColumns();

  // Native embedded pie chart over the category data.
  final charts = ChartCollection(sheet);
  final chart = charts.add();
  chart.chartType = ExcelChartType.pie;
  chart.dataRange = sheet.getRangeByName('A3:B$lastRow');
  chart.isSeriesInRows = false;
  chart.chartTitle = title;
  chart.hasLegend = true;
  chart.topRow = 2;
  chart.leftColumn = 4;
  chart.bottomRow = 20;
  chart.rightColumn = 12;
  sheet.charts = charts;

  final bytes = workbook.saveAsStream();
  workbook.dispose();
  return bytes;
}
