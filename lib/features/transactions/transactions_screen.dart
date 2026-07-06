import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/confirm_dialogs.dart';
import '../../shared/money.dart';
import '../../shared/widgets/empty_state.dart';
import 'transaction_editor.dart';
import 'tx_tile.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  String _query = '';
  final Set<TxType> _types = {};
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleType(TxType t) {
    setState(() {
      if (_types.contains(t)) {
        _types.remove(t);
      } else {
        _types.add(t);
      }
    });
  }

  bool get _hasFilter => _query.isNotEmpty || _types.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search notes, categories…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Activity'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                _query = '';
              }
            }),
          ),
          if (!_searching)
            IconButton(
              tooltip: 'New transaction',
              icon: const Icon(Icons.add),
              onPressed: () => TransactionEditor.open(context),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(types: _types, onToggle: _toggleType),
          Expanded(
            child: StreamBuilder<List<TxWithRefs>>(
              stream: db.watchTransactionsFiltered(
                  query: _query, types: _types),
              builder: (context, snap) {
                final items = snap.data ?? const [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return _hasFilter
                      ? const EmptyState(
                          icon: Icons.search_off,
                          title: 'No matches',
                          message: 'Try a different search or clear the '
                              'filters above.',
                        )
                      : const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No activity yet',
                          message: 'Tap + here or the big button below to log '
                              'your first transaction.',
                        );
                }
                return _GroupedList(items: items, showTotal: _hasFilter);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.types, required this.onToggle});
  final Set<TxType> types;
  final void Function(TxType) onToggle;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, TxType t) {
      final on = types.contains(t);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: on,
          onSelected: (_) => onToggle(t),
          showCheckmark: false,
          selectedColor: MunshiTheme.accentDeep,
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('Expense', TxType.expense),
          chip('Income', TxType.income),
          chip('Transfer', TxType.transfer),
        ],
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.items, this.showTotal = false});

  final List<TxWithRefs> items;
  final bool showTotal;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    if (showTotal) {
      final expense = items
          .where((i) => i.tx.type == TxType.expense)
          .fold<int>(0, (s, i) => s + i.tx.amountMinor);
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text(
          '${items.length} result${items.length == 1 ? "" : "s"} · '
          '${Money.format(expense)} spent',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: MunshiTheme.accent, fontWeight: FontWeight.w600),
        ),
      ));
    }

    String? currentDay;
    for (final item in items) {
      final heading = Money.dayHeading(item.tx.occurredAt);
      if (heading != currentDay) {
        currentDay = heading;
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Text(
            heading,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.white54, fontWeight: FontWeight.w700),
          ),
        ));
      }
      widgets.add(Dismissible(
        key: ValueKey(item.tx.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => ConfirmDialogs.confirmDelete(
          context,
          title: 'Delete this ${Money.format(item.tx.amountMinor)} entry?',
          subtitle:
              '${item.category?.name ?? "Uncategorized"} · This can\'t be undone.',
        ),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: Colors.red.withValues(alpha: 0.2),
          child: const Icon(Icons.delete_outline, color: Colors.redAccent),
        ),
        onDismissed: (_) async {
          final messenger = ScaffoldMessenger.of(context);
          await db.deleteTx(item.tx.id);
          messenger.showSnackBar(const SnackBar(
            content: Text('Deleted'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        child: TxTile(
          item: item,
          onTap: () => TransactionEditor.open(context, existing: item.tx),
        ),
      ));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: widgets,
    );
  }
}
