import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db.dart';
import '../../shared/money.dart';
import 'excel_exporter.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late DateTime _from;
  late DateTime _to;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0); // last day of month
  }

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => isFrom ? _from = picked : _to = picked);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final rangeStart = DateTime(_from.year, _from.month, _from.day);
      final rangeEnd =
          DateTime(_to.year, _to.month, _to.day).add(const Duration(days: 1));
      final txns = await db.watchTxInRange(rangeStart, rangeEnd).first;
      final cats = await db.allCategories();
      final accts = await db.activeAccountsAll();
      final balances = await db.watchAccountBalances().first;

      final bytes = buildFullReport(
        from: rangeStart,
        to: DateTime(_to.year, _to.month, _to.day),
        txns: txns,
        catById: {for (final c in cats) c.id: c},
        acctById: {for (final a in accts) a.id: a},
        balances: balances,
      );

      final dir = await getTemporaryDirectory();
      final stamp = '${_from.year}${_from.month.toString().padLeft(2, '0')}'
          '-${_to.year}${_to.month.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/munshi_export_$stamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Munshi export $stamp',
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export to Excel')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Date range',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _DateTile(
                      label: 'From',
                      value: Money.dateLabel(_from),
                      onTap: () => _pick(true))),
              const SizedBox(width: 12),
              Expanded(
                  child: _DateTile(
                      label: 'To',
                      value: Money.dateLabel(_to),
                      onTap: () => _pick(false))),
            ],
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The workbook includes',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  _Bullet('Transactions — full log for the range'),
                  _Bullet('Categories — totals + pie chart'),
                  _Bullet('Accounts — balances + bar chart'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_busy ? 'Generating…' : 'Generate & share'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: Colors.white54)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
