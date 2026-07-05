import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../services/alerts_service.dart';
import '../../services/receipt_service.dart';
import '../../services/widget_service.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';

/// Full add/edit form. Handles expense, income, and transfer entry.
class TransactionEditor extends StatefulWidget {
  const TransactionEditor({super.key, this.existing});

  final TxRow? existing;

  static Future<void> open(BuildContext context, {TxRow? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionEditor(existing: existing)),
    );
  }

  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<TransactionEditor> {
  late TxType _type;
  late TextEditingController _amount;
  late TextEditingController _note;
  late DateTime _date;
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  String? _receiptPath;

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? TxType.expense;
    _amount = TextEditingController(
        text: e == null ? '' : (e.amountMinor / 100).toStringAsFixed(2));
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.occurredAt ?? DateTime.now();
    _accountId = e?.accountId;
    _toAccountId = e?.transferToAccountId;
    _categoryId = e?.categoryId;
    _receiptPath = e?.receiptPath;
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // All accounts (incl. archived) so transactions on archived accounts stay
    // editable — a value missing from the dropdown's items would assert.
    final accounts = await db.activeAccountsAll();
    final categories = await db.allCategories();
    if (!mounted) return;
    final active = accounts.where((a) => !a.isArchived).toList();
    setState(() {
      _accounts = accounts;
      _categories = categories;
      _accountId ??= active.isNotEmpty
          ? active.first.id
          : (accounts.isNotEmpty ? accounts.first.id : null);
      _loading = false;
    });
  }

  List<Category> get _catsForType =>
      _categories.where((c) => c.kind == _type).toList();

  Future<void> _save() async {
    final minor = Money.toMinor(_amount.text);
    if (minor <= 0 || _accountId == null) {
      _toast('Enter an amount and account');
      return;
    }
    if (_type == TxType.transfer &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      _toast('Pick a different destination account');
      return;
    }
    if (_type != TxType.transfer && _categoryId == null) {
      _toast('Pick a category');
      return;
    }

    final e = widget.existing;
    if (e == null) {
      await db.insertTx(TransactionsCompanion.insert(
        occurredAt: _date,
        amountMinor: minor,
        type: _type,
        accountId: _accountId!,
        categoryId: Value(_type == TxType.transfer ? null : _categoryId),
        transferToAccountId:
            Value(_type == TxType.transfer ? _toAccountId : null),
        note: Value(_note.text.trim().isEmpty ? null : _note.text.trim()),
        receiptPath: Value(_receiptPath),
      ));
    } else {
      await db.updateTx(e.copyWith(
        occurredAt: _date,
        amountMinor: minor,
        type: _type,
        accountId: _accountId!,
        categoryId: Value(_type == TxType.transfer ? null : _categoryId),
        transferToAccountId:
            Value(_type == TxType.transfer ? _toAccountId : null),
        note: Value(_note.text.trim().isEmpty ? null : _note.text.trim()),
        receiptPath: Value(_receiptPath),
      ));
    }
    if (_type == TxType.expense) {
      await AlertsService.instance.checkAfterExpense(_categoryId);
    }
    await WidgetService.instance.refresh();
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
      );

  Future<void> _confirmDelete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await db.deleteTx(e.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit transaction' : 'New transaction'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SegmentedButton<TxType>(
                  segments: const [
                    ButtonSegment(value: TxType.expense, label: Text('Expense')),
                    ButtonSegment(value: TxType.income, label: Text('Income')),
                    ButtonSegment(
                        value: TxType.transfer, label: Text('Transfer')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() {
                    _type = s.first;
                    _categoryId = null;
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _accountField(
                  label: _type == TxType.transfer ? 'From account' : 'Account',
                  value: _accountId,
                  onChanged: (v) => setState(() => _accountId = v),
                ),
                if (_type == TxType.transfer) ...[
                  const SizedBox(height: 16),
                  _accountField(
                    label: 'To account',
                    value: _toAccountId,
                    onChanged: (v) => setState(() => _toAccountId = v),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  _categoryField(),
                ],
                const SizedBox(height: 16),
                _dateField(),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _receiptField(),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(editing ? 'Save changes' : 'Add transaction'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _accountField({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()),
      items: [
        for (final a in _accounts)
          DropdownMenuItem(
            value: a.id,
            child: Row(children: [
              Icon(iconFor(a.iconKey), size: 18),
              const SizedBox(width: 8),
              Text(a.name),
            ]),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _categoryField() {
    final cats = _catsForType;
    return DropdownButtonFormField<int>(
      initialValue: cats.any((c) => c.id == _categoryId) ? _categoryId : null,
      decoration: const InputDecoration(
          labelText: 'Category', border: OutlineInputBorder()),
      items: [
        for (final c in cats)
          DropdownMenuItem(
            value: c.id,
            child: Row(children: [
              Icon(iconFor(c.iconKey), size: 18, color: Color(c.colorValue)),
              const SizedBox(width: 8),
              Text(c.name),
            ]),
          ),
      ],
      onChanged: (v) => setState(() => _categoryId = v),
    );
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await ReceiptService.instance.pick(source);
    if (path != null && mounted) setState(() => _receiptPath = path);
  }

  void _viewReceipt() {
    if (_receiptPath == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ReceiptViewer(path: _receiptPath!),
    ));
  }

  Widget _receiptField() {
    if (_receiptPath == null) {
      return OutlinedButton.icon(
        onPressed: _pickReceipt,
        icon: const Icon(Icons.attachment, size: 18),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Attach receipt'),
        ),
      );
    }
    final file = File(_receiptPath!);
    return Row(
      children: [
        GestureDetector(
          onTap: _viewReceipt,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: file.existsSync()
                ? Image.file(file,
                    width: 64, height: 64, fit: BoxFit.cover)
                : Container(
                    width: 64,
                    height: 64,
                    color: MunshiTheme.surfaceHigh,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.white38),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Receipt attached',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _receiptPath = null),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Remove'),
          style: TextButton.styleFrom(foregroundColor: MunshiTheme.negative),
        ),
      ],
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2015),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) {
          setState(() => _date =
              DateTime(picked.year, picked.month, picked.day,
                  _date.hour, _date.minute));
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
            labelText: 'Date', border: OutlineInputBorder()),
        child: Text(Money.dateLabel(_date)),
      ),
    );
  }
}

/// Full-screen pinch-zoom receipt viewer.
class _ReceiptViewer extends StatelessWidget {
  const _ReceiptViewer({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Receipt'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}
