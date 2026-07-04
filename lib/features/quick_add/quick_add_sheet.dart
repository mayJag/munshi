import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// The 2-tap quick-add centerpiece — a numeric keypad sheet with the amount
/// pre-focused, then a category chip. This is the skeleton UI; wiring to the
/// data layer lands in Phase 1.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddSheet(),
    );
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  String _amount = '0';

  static const _categories = [
    ('Food', Icons.restaurant),
    ('Transport', Icons.directions_bus),
    ('Shopping', Icons.shopping_bag),
    ('Bills', Icons.receipt_long),
    ('Health', Icons.favorite),
    ('Fun', Icons.movie),
  ];

  void _tap(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == '<') {
        _amount = _amount.length > 1
            ? _amount.substring(0, _amount.length - 1)
            : '0';
      } else if (key == '.') {
        if (!_amount.contains('.')) _amount = '$_amount.';
      } else {
        _amount = _amount == '0' ? key : '$_amount$key';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: MunshiTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text('Add expense',
              style: theme.textTheme.labelLarge?.copyWith(color: Colors.white54)),
          const SizedBox(height: 8),
          Text(
            '₹$_amount',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (label, icon) = _categories[i];
                return ActionChip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Saved ₹$_amount · $label (demo)'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _Keypad(onTap: _tap),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onTap});

  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '<'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.9,
      children: [
        for (final k in keys)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onTap(k),
            child: Center(
              child: k == '<'
                  ? const Icon(Icons.backspace_outlined)
                  : Text(
                      k,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
            ),
          ),
      ],
    );
  }
}
