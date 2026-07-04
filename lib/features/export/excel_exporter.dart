import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:syncfusion_officechart/officechart.dart';

/// A single category's spend, used to build the export summary + chart.
class CategorySpend {
  const CategorySpend(this.category, this.amount);
  final String category;
  final double amount;
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
