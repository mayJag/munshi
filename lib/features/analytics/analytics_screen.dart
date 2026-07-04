import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: const EmptyState(
        icon: Icons.insights_outlined,
        title: 'Nothing to analyze yet',
        message: 'Category donuts, trends, and month-over-month comparisons '
            'appear once you have some transactions.',
      ),
    );
  }
}
