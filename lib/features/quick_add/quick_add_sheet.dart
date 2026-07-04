import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/money.dart';
import '../../services/alerts_service.dart';
import '../categories/category_editor_sheet.dart';

/// The 2-tap quick-add centerpiece: amount keypad + category grid. Saves an
/// expense to the selected account. Reachable via FAB and notification tap.
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
  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  Account? _account;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await db.activeAccounts();
    final categories = await db.watchCategories(TxType.expense).first;
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _categories = categories;
      _account = accounts.isNotEmpty ? accounts.first : null;
      _loading = false;
    });
  }

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

  Future<void> _save(Category category) async {
    final minor = Money.toMinor(_amount);
    if (minor <= 0 || _account == null || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    await db.insertTx(TransactionsCompanion.insert(
      occurredAt: DateTime.now(),
      amountMinor: minor,
      type: TxType.expense,
      accountId: _account!.id,
      categoryId: Value(category.id),
    ));
    await AlertsService.instance.checkAfterExpense(category.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved ${Money.format(minor)} · ${category.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
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
                const SizedBox(height: 16),
                _accountSelector(theme),
                const SizedBox(height: 8),
                Text('₹$_amount',
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _categoryGrid(),
                const SizedBox(height: 12),
                _Keypad(onTap: _tap),
              ],
            ),
    );
  }

  Widget _accountSelector(ThemeData theme) {
    if (_accounts.isEmpty) {
      return Text('No account — add one first',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54));
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<Account>(
        value: _account,
        isDense: true,
        borderRadius: BorderRadius.circular(12),
        dropdownColor: MunshiTheme.surfaceHigh,
        items: [
          for (final a in _accounts)
            DropdownMenuItem(
              value: a,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconFor(a.iconKey), size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(a.name),
                ],
              ),
            ),
        ],
        onChanged: (a) => setState(() => _account = a),
      ),
    );
  }

  Widget _categoryGrid() {
    return SizedBox(
      height: 96,
      child: GridView.count(
        scrollDirection: Axis.horizontal,
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.42,
        children: [
          for (final c in _categories)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _save(c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Color(c.colorValue).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconFor(c.iconKey),
                        size: 18, color: Color(c.colorValue)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(c.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              await CategoryEditorSheet.show(context,
                  initialKind: TxType.expense);
              await _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: Colors.white70),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text('New',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
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
                  : Text(k, style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
      ],
    );
  }
}
