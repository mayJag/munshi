import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/db.dart';
import '../../shared/icons/app_icons.dart';
import 'category_editor_sheet.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'New category',
            icon: const Icon(Icons.add),
            onPressed: () => CategoryEditorSheet.show(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Category>>(
        stream: db.watchAllCategories(),
        builder: (context, snap) {
          final cats = snap.data ?? const [];
          if (cats.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final expense =
              cats.where((c) => c.kind == TxType.expense).toList();
          final income = cats.where((c) => c.kind == TxType.income).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _header(context, 'Expense'),
              for (final c in expense) _tile(context, c),
              const SizedBox(height: 12),
              _header(context, 'Income'),
              for (final c in income) _tile(context, c),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.white54, fontWeight: FontWeight.w700)),
      );

  Widget _tile(BuildContext context, Category c) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(c.colorValue).withValues(alpha: 0.18),
        child: Icon(iconFor(c.iconKey), color: Color(c.colorValue), size: 20),
      ),
      title: Text(c.name),
      subtitle: c.isCustom ? const Text('Custom') : null,
      onTap: () => CategoryEditorSheet.show(context, existing: c),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'edit') {
            if (context.mounted) {
              CategoryEditorSheet.show(context, existing: c);
            }
          } else if (v == 'delete') {
            final messenger = ScaffoldMessenger.of(context);
            await db.deleteCategory(c.id);
            messenger.showSnackBar(SnackBar(
              content: Text('Deleted ${c.name}'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
