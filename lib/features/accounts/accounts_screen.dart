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
          if (balances.isEmpty) {
            return _EmptyState(onAdd: () => AccountEditorSheet.show(context));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _NetCard(net: net, count: balances.length),
              const SizedBox(height: 20),
              Text('All accounts',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.white38)),
              const SizedBox(height: 10),
              for (final b in balances) ...[
                _AccountCard(balance: b),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Net worth hero card ───────────────────────────────────────────────────────

class _NetCard extends StatelessWidget {
  const _NetCard({required this.net, required this.count});
  final int net;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = net >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MunshiTheme.accentDeep, Color(0xFF0A2E2B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net worth',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: Colors.white60)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count ${count == 1 ? "account" : "accounts"}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.white54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            Money.format(net),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: positive ? Colors.white : MunshiTheme.negative,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            positive ? 'Your total across all accounts' : 'Net deficit',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

// ── Individual account card ───────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.balance});
  final AccountBalance balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = balance.account;
    final color = Color(a.colorValue);
    final bal = balance.balanceMinor;
    final isNegative = bal < 0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Color strip on the left (like Cashew)
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconFor(a.iconKey), color: color, size: 20),
                    ),
                    const SizedBox(width: 12),

                    // Name + type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(a.name,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            _typeLabel(a.type),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white38),
                          ),
                        ],
                      ),
                    ),

                    // Balance — always gets space, not in a trailing constraint
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          Money.format(bal),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isNegative
                                ? MunshiTheme.negative
                                : Colors.white,
                          ),
                        ),
                        Text(
                          isNegative ? 'Overdrawn' : 'Balance',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white38),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),

                    // 3-dot menu — separated from balance so it can't overlap
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert,
                          size: 20, color: Colors.white38),
                      onSelected: (v) async {
                        if (v == 'archive') {
                          await db.setAccountArchived(a.id, true);
                        } else if (v == 'edit') {
                          if (context.mounted) {
                            AccountEditorSheet.show(context, existing: a);
                          }
                        } else if (v == 'delete') {
                          if (context.mounted) {
                            await _confirmDelete(context, a);
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                            value: 'archive', child: Text('Archive')),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style:
                                    TextStyle(color: MunshiTheme.negative))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(AccountType t) {
    switch (t) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank account';
      case AccountType.card:
        return 'Credit / Debit card';
      case AccountType.wallet:
        return 'Wallet';
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _confirmDelete(BuildContext context, Account a) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Delete ${a.name}?'),
      content: const Text(
          'This permanently removes the account and all its transactions. '
          'To just hide it, use Archive instead.'),
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
  await db.deleteAccountCascade(a.id);
  messenger.showSnackBar(SnackBar(
    content: Text('Deleted ${a.name}'),
    behavior: SnackBarBehavior.floating,
  ));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 56, color: Colors.white24),
          const SizedBox(height: 16),
          Text('No accounts yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white54)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add your first account'),
          ),
        ],
      ),
    );
  }
}
