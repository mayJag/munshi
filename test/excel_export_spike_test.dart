// Phase-0 Spike 1: prove syncfusion_flutter_xlsio can emit an .xlsx with a
// native embedded pie chart. Writes a real file to build/ for manual opening.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munshi/features/export/excel_exporter.dart';

void main() {
  test('builds an .xlsx with an embedded pie chart', () {
    const spends = [
      CategorySpend('Food', 8200),
      CategorySpend('Transport', 3100),
      CategorySpend('Shopping', 5400),
      CategorySpend('Bills', 6750),
      CategorySpend('Health', 1900),
      CategorySpend('Fun', 2600),
    ];

    final bytes = buildCategoryReport(spends: spends);

    expect(bytes, isNotEmpty);
    // .xlsx is a zip archive — verify the PK magic bytes.
    expect(bytes[0], 0x50); // P
    expect(bytes[1], 0x4B); // K

    final outDir = Directory('build')..createSync(recursive: true);
    final file = File('${outDir.path}/munshi_spike_export.xlsx');
    file.writeAsBytesSync(bytes, flush: true);
    // ignore: avoid_print
    print('Wrote ${bytes.length} bytes -> ${file.absolute.path}');
  });
}
