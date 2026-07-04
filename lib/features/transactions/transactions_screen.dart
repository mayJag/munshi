import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No activity yet',
        message: 'Your transactions, grouped by day, will show up here once '
            'you start logging.',
      ),
    );
  }
}
