import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';

/// Create or edit a recurring template (rent, salary, subscriptions…).
class RecurringEditorSheet extends StatefulWidget {
  const RecurringEditorSheet({super.key, this.existing});

  final RecurringTemplate? existing;

  static Future<void> show(BuildContext context,
      {RecurringTemplate? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: RecurringEditorSheet(existing: existing),
      ),
    );
  }

  @override
  State<RecurringEditorSheet> createState() => _RecurringEditorSheetState();
}

class _RecurringEditorSheetState extends State<RecurringEditorSheet> {
  late TextEditingController _name;
  late TextEditingController _amount;
  late TxType _type;
  late Frequency _freq;
  late DateTime _nextDue;
  int? _accountId;
  int? _categoryId;

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _amount = TextEditingController(
        text: e == null ? '' : (e.amountMinor / 100).toStringAsFixed(2));
    _type = e?.type ?? TxType.expense;
    _freq = e?.frequency ?? Frequency.monthly;
    _nextDue = e?.nextDueDate ?? DateTime.now();
    _accountId = e?.accountId;
    _categoryId = e?.categoryId;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Include archived accounts so an existing template stays editable.
    final a = await db.activeAccountsAll();
    final c = await db.allCategories();
    if (!mounted) return;
    final active = a.where((x) => !x.isArchived).toList();
    setState(() {
      _accounts = a;
      _categories = c;
      _accountId ??= active.isNotEmpty
          ? active.first.id
          : (a.isNotEmpty ? a.first.id : null);
      _loading = false;
    });
  }

  List<Category> get _cats =>
      _categories.where((c) => c.kind == _type).toList();

  Future<void> _save() async {
    final name = _name.text.trim();
    final minor = Money.toMinor(_amount.text);
    if (name.isEmpty || minor <= 0 || _accountId == null) return;
    final e = widget.existing;
    if (e == null) {
      await db.insertRecurring(RecurringTemplatesCompanion.insert(
        name: name,
        amountMinor: minor,
        type: Value(_type),
        accountId: _accountId!,
        categoryId: Value(_categoryId),
        frequency: Value(_freq),
        nextDueDate: _nextDue,
      ));
    } else {
      await db.updateRecurring(e.copyWith(
        name: name,
        amountMinor: minor,
        type: _type,
        accountId: _accountId!,
        categoryId: Value(_categoryId),
        frequency: _freq,
        nextDueDate: _nextDue,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator()));
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing == null ? 'New recurring' : 'Edit recurring',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Name (e.g. Rent)',
                    border: OutlineInputBorder()),
              ),
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
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                    labelText: 'Account', border: OutlineInputBorder()),
                items: [
                  for (final a in _accounts)
                    DropdownMenuItem(
                        value: a.id,
                        child: Row(children: [
                          Icon(iconFor(a.iconKey), size: 18),
                          const SizedBox(width: 8),
                          Text(a.name),
                        ])),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue:
                    _cats.any((c) => c.id == _categoryId) ? _categoryId : null,
                decoration: const InputDecoration(
                    labelText: 'Category', border: OutlineInputBorder()),
                items: [
                  for (final c in _cats)
                    DropdownMenuItem(
                        value: c.id,
                        child: Row(children: [
                          Icon(iconFor(c.iconKey),
                              size: 18, color: Color(c.colorValue)),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ])),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Frequency>(
                initialValue: _freq,
                decoration: const InputDecoration(
                    labelText: 'Repeats', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: Frequency.daily, child: Text('Daily')),
                  DropdownMenuItem(
                      value: Frequency.weekly, child: Text('Weekly')),
                  DropdownMenuItem(
                      value: Frequency.monthly, child: Text('Monthly')),
                ],
                onChanged: (v) =>
                    setState(() => _freq = v ?? Frequency.monthly),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextDue,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _nextDue = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Next due', border: OutlineInputBorder()),
                  child: Text(Money.dateLabel(_nextDue)),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
