import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/swatches.dart';

/// Create or edit a custom category (name, kind, icon, color).
class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet({super.key, this.existing, this.initialKind});

  final Category? existing;
  final TxType? initialKind;

  static Future<void> show(BuildContext context,
      {Category? existing, TxType? initialKind}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CategoryEditorSheet(
            existing: existing, initialKind: initialKind),
      ),
    );
  }

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  late TextEditingController _name;
  late TxType _kind;
  late String _iconKey;
  late int _color;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _kind = e?.kind ?? widget.initialKind ?? TxType.expense;
    _iconKey = e?.iconKey ?? 'other';
    _color = e?.colorValue ?? kSwatches.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final e = widget.existing;
    if (e == null) {
      final all = await db.allCategories();
      final maxOrder = all.isEmpty
          ? 0
          : all.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);
      await db.insertCategory(CategoriesCompanion.insert(
        name: name,
        kind: Value(_kind),
        iconKey: Value(_iconKey),
        colorValue: Value(_color),
        isCustom: const Value(true),
        sortOrder: Value(maxOrder + 1),
      ));
    } else {
      await db.updateCategoryRow(e.copyWith(
        name: name,
        kind: _kind,
        iconKey: _iconKey,
        colorValue: _color,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final iconKeys = kAppIcons.keys.toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'New category' : 'Edit category',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(value: TxType.expense, label: Text('Expense')),
                ButtonSegment(value: TxType.income, label: Text('Income')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            Text('Icon', style: TextStyle(color: context.cMuted)),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: iconKeys.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final key = iconKeys[i];
                  final sel = key == _iconKey;
                  return GestureDetector(
                    onTap: () => setState(() => _iconKey = key),
                    child: CircleAvatar(
                      backgroundColor: sel
                          ? Color(_color)
                          : context.cHair,
                      child: Icon(iconFor(key),
                          color: sel ? Colors.white : context.cMuted, size: 20),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Color', style: TextStyle(color: context.cMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in kSwatches)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? context.cText : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
