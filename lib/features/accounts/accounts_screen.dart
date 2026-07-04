import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';
import 'account_editor_sheet.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'New account',
            icon: const Icon(Icons.add),
            onPressed: () => AccountEditorSheet.show(context),
          ),
        ],
      ),
      body: StreamBuilder<List<AccountBalance>>(
        stream: db.watchAccountBalances(),
        builder: (context, snap) {
          final balances = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final net =
              balances.fold<int>(0, (s, b) => s + b.balanceMinor);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _NetCard(net: net, count: balances.length),
              const SizedBox(height: 16),
              for (final b in balances) _AccountCard(balance: b),
            ],
          );
        },
      ),
    );
  }
}

class _NetCard extends StatelessWidget {
  const _NetCard({required this.net, required this.count});
  final int net;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MunshiTheme.accentDeep, Color(0xFF0B3B36)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net balance',
              style:
                  theme.textTheme.labelLarge?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(Money.format(net),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
          Text('across $count ${count == 1 ? "account" : "accounts"}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.balance});
  final AccountBalance balance;

  @override
  Widget build(BuildContext context) {
    final a = balance.account;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => AccountEditorSheet.show(context, existing: a),
        leading: CircleAvatar(
          backgroundColor: Color(a.colorValue).withValues(alpha: 0.18),
          child: Icon(iconFor(a.iconKey), color: Color(a.colorValue)),
        ),
        title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(a.type.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Money.format(balance.balanceMinor),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'archive') {
                  await db.setAccountArchived(a.id, true);
                } else if (v == 'edit') {
                  if (context.mounted) {
                    AccountEditorSheet.show(context, existing: a);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
