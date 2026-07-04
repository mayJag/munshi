import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';

/// Add or edit an account. Opening balance is entered in rupees, stored as paise.
class AccountEditorSheet extends StatefulWidget {
  const AccountEditorSheet({super.key, this.existing});

  final Account? existing;

  static Future<void> show(BuildContext context, {Account? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AccountEditorSheet(existing: existing),
      ),
    );
  }

  @override
  State<AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<AccountEditorSheet> {
  late TextEditingController _name;
  late TextEditingController _opening;
  late AccountType _type;

  static const _iconForType = {
    AccountType.cash: 'cash',
    AccountType.bank: 'bank',
    AccountType.card: 'card',
    AccountType.wallet: 'wallet',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _opening = TextEditingController(
        text: e == null ? '' : (e.openingBalanceMinor / 100).toStringAsFixed(2));
    _type = e?.type ?? AccountType.cash;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final opening = Money.toMinor(_opening.text);
    final iconKey = _iconForType[_type]!;
    final e = widget.existing;
    if (e == null) {
      await db.insertAccount(AccountsCompanion.insert(
        name: name,
        type: _type,
        openingBalanceMinor: Value(opening),
        iconKey: Value(iconKey),
      ));
    } else {
      await db.updateAccount(e.copyWith(
        name: name,
        type: _type,
        openingBalanceMinor: opening,
        iconKey: iconKey,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'New account' : 'Edit account',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: const InputDecoration(
                  labelText: 'Type', border: OutlineInputBorder()),
              items: [
                for (final t in AccountType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Row(children: [
                      Icon(iconFor(_iconForType[t]!), size: 18),
                      const SizedBox(width: 8),
                      Text(t.name[0].toUpperCase() + t.name.substring(1)),
                    ]),
                  ),
              ],
              onChanged: (t) => setState(() => _type = t ?? AccountType.cash),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _opening,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Opening balance',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
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
    );
  }
}
