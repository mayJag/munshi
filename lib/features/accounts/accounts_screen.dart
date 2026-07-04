import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No accounts yet',
        message: 'Add cash, bank, card, or wallet accounts to see balances '
            'and a consolidated net worth.',
      ),
    );
  }
}
