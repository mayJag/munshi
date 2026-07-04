import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/money.dart';
import '../../shared/widgets/empty_state.dart';
import 'transaction_editor.dart';
import 'tx_tile.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: 'New transaction',
            icon: const Icon(Icons.add),
            onPressed: () => TransactionEditor.open(context),
          ),
        ],
      ),
      body: StreamBuilder<List<TxWithRefs>>(
        stream: db.watchTransactions(),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No activity yet',
              message: 'Tap + here or the big button below to log your first '
                  'transaction.',
            );
          }
          return _GroupedList(items: items);
        },
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.items});

  final List<TxWithRefs> items;

  @override
  Widget build(BuildContext context) {
    // Build a flat list of headers + tiles grouped by day.
    final widgets = <Widget>[];
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
