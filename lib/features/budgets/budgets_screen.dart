import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: const EmptyState(
        icon: Icons.pie_chart_outline,
        title: 'No budgets set',
        message: 'Set monthly limits per category and Munshi will track '
            'budget-vs-actual for you.',
      ),
    );
  }
}
