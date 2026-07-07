import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Shared confirmation sheets — destructive delete and pre-save review —
/// matching the redesigned gold/ink identity. Both return true if the user
/// confirmed, false/null if cancelled.
class ConfirmDialogs {
  ConfirmDialogs._();

  static Widget _grabber() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      );

  /// Bottom sheet confirming a destructive delete.
  static Future<bool> confirmDelete(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            const SizedBox(height: 18),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.delete_outline,
                  color: theme.colorScheme.error, size: 26),
            ),
            const SizedBox(height: 14),
            Text(title,
                style:
                    theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// Compact "confirm & save" step shown before a transaction actually
  /// commits — used by the quick-add sheet.
  static Future<bool> confirmLog(
    BuildContext context, {
    required String amountLabel,
    required String detailLabel,
    required IconData icon,
    required Color color,
  }) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            const SizedBox(height: 18),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 14),
            Text('Confirm this expense', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(amountLabel,
                style: theme.textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(detailLabel, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: MunshiTheme.gold,
                        foregroundColor: MunshiTheme.onGoldDark),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Confirm & save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }
}
