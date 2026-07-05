import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';

/// One transaction row, shared by the list and the dashboard's recent section.
class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.item, this.onTap});

  final TxWithRefs item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tx = item.tx;
    final isIncome = tx.type == TxType.income;
    final isTransfer = tx.type == TxType.transfer;

    final Color color = isTransfer
        ? Colors.white54
        : isIncome
            ? MunshiTheme.positive
            : Color(item.category?.colorValue ?? 0xFF64748B);

    final IconData icon = isTransfer
        ? Icons.swap_horiz
        : iconFor(item.category?.iconKey ?? 'other');

    final String title = isTransfer
        ? '${item.account?.name ?? '?'} → ${item.toAccount?.name ?? '?'}'
        : item.category?.name ?? 'Uncategorized';

    final String sign = isIncome ? '+' : isTransfer ? '' : '−';
    final String subtitle = [
      if (!isTransfer) item.account?.name,
      if (tx.note != null && tx.note!.isNotEmpty) tx.note,
    ].whereType<String>().join(' · ');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tx.receiptPath != null) ...[
            const Icon(Icons.attachment, size: 14, color: Colors.white38),
            const SizedBox(width: 4),
          ],
          Text(
            '$sign${Money.format(tx.amountMinor)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isIncome ? MunshiTheme.positive : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
