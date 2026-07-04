import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../data/db.dart';

/// Import transactions from a generic CSV via a column-mapping wizard.
class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  List<List<dynamic>> _rows = const [];
  List<String> _headers = const [];
  bool _hasHeader = true;

  int? _dateCol;
  int? _amountCol;
  int? _noteCol;
  TxType _type = TxType.expense;

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  int? _accountId;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    final a = await db.activeAccounts();
    final c = await db.allCategories();
    if (!mounted) return;
    setState(() {
      _accounts = a;
      _categories = c;
      _accountId = a.isNotEmpty ? a.first.id : null;
    });
  }

  List<Category> get _cats =>
      _categories.where((c) => c.kind == _type).toList();

  Future<void> _pickFile() async {
    const group = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final content = await file.readAsString();
    final rows = Csv(dynamicTyping: false).decode(content);
    if (rows.isEmpty) return;
    setState(() {
      _rows = rows;
      _headers = _hasHeader
          ? rows.first.map((e) => e.toString()).toList()
          : List.generate(rows.first.length, (i) => 'Column ${i + 1}');
      _dateCol = null;
      _amountCol = null;
      _noteCol = null;
    });
  }

  DateTime _parseDate(String s) {
    final direct = DateTime.tryParse(s.trim());
    if (direct != null) return direct;
    for (final f in ['dd/MM/yyyy', 'dd-MM-yyyy', 'MM/dd/yyyy', 'd MMM yyyy']) {
      try {
        return DateFormat(f).parseStrict(s.trim());
      } catch (_) {}
    }
    return DateTime.now();
  }

  int _parseAmount(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final v = double.tryParse(cleaned) ?? 0;
    return (v.abs() * 100).round();
  }

  Future<void> _import() async {
    if (_amountCol == null || _accountId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dataRows = _hasHeader ? _rows.skip(1) : _rows;
    var count = 0;
    for (final row in dataRows) {
      if (row.length <= _amountCol!) continue;
      final minor = _parseAmount(row[_amountCol!].toString());
      if (minor <= 0) continue;
      final when = _dateCol != null && row.length > _dateCol!
          ? _parseDate(row[_dateCol!].toString())
          : DateTime.now();
      final note = _noteCol != null && row.length > _noteCol!
          ? row[_noteCol!].toString()
          : null;
      await db.insertTx(TransactionsCompanion.insert(
        occurredAt: when,
        amountMinor: minor,
        type: _type,
        accountId: _accountId!,
        categoryId: Value(_type == TxType.transfer ? null : _categoryId),
        note: Value(note == null || note.isEmpty ? null : note),
      ));
      count++;
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Imported $count transactions'),
      behavior: SnackBarBehavior.floating,
    ));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _rows.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(loaded ? 'Choose a different file' : 'Choose CSV file'),
            ),
          ),
          if (loaded) ...[
            const SizedBox(height: 8),
            Text('${_rows.length} rows read',
                style: const TextStyle(color: Colors.white54)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('First row is a header'),
              value: _hasHeader,
              onChanged: (v) => setState(() {
                _hasHeader = v;
                _headers = v
                    ? _rows.first.map((e) => e.toString()).toList()
                    : List.generate(
                        _rows.first.length, (i) => 'Column ${i + 1}');
              }),
            ),
            const Divider(),
            const Text('Map columns',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _colDropdown('Amount column', _amountCol,
                (v) => setState(() => _amountCol = v)),
            _colDropdown('Date column (optional)', _dateCol,
                (v) => setState(() => _dateCol = v)),
            _colDropdown('Note column (optional)', _noteCol,
                (v) => setState(() => _noteCol = v)),
            const SizedBox(height: 12),
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(value: TxType.expense, label: Text('Expense')),
                ButtonSegment(value: TxType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) =>
                  setState(() { _type = s.first; _categoryId = null; }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: const InputDecoration(
                  labelText: 'Into account', border: OutlineInputBorder()),
              items: [
                for (final a in _accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue:
                  _cats.any((c) => c.id == _categoryId) ? _categoryId : null,
              decoration: const InputDecoration(
                  labelText: 'Default category', border: OutlineInputBorder()),
              items: [
                for (final c in _cats)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _amountCol == null ? null : _import,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Import'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _colDropdown(String label, int? value, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [
          for (var i = 0; i < _headers.length; i++)
            DropdownMenuItem(value: i, child: Text(_headers[i])),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
