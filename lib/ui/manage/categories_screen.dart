import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import 'category_editor.dart';
import '../../core/i18n.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('ক্যাটাগরি', 'Categories')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('খরচ', 'Expense')),
              Tab(text: tr('জমা', 'Income')),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () =>
                showCategoryEditor(context, ref, kind: DefaultTabController.of(context).index),
            icon: const Icon(Icons.add),
            label: Text(tr('নতুন', 'New')),
          ),
        ),
        body: const TabBarView(children: [_CatList(kind: 0), _CatList(kind: 1)]),
      ),
    );
  }
}

class _CatList extends ConsumerWidget {
  const _CatList({required this.kind});
  final int kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(categoriesProvider).value ?? const <Cat>[];
    final cats = all.where((c) => c.kind == kind && !c.archived).toList();
    final archived = all.where((c) => c.kind == kind && c.archived).toList();
    final fin = ref.watch(financeProvider);
    final counts = <int, int>{};
    for (final t in fin.txns) {
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              tr(
                'ধরে রেখে টেনে ক্রম বদলান · ট্যাপ করে এডিট',
                'Hold and drag to reorder · tap to edit',
              ),
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
        SliverReorderableList(
          itemCount: cats.length,
          onReorderItem: (oldI, newI) {
            final list = [...cats];
            final item = list.removeAt(oldI);
            list.insert(newI, item);
            ref.read(repoProvider).reorderCategories(list);
          },
          itemBuilder: (context, i) {
            final c = cats[i];
            return ReorderableDelayedDragStartListener(
              key: ValueKey(c.id),
              index: i,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: CatAvatar.of(c),
                  title: Text(c.name),
                  subtitle: Text(
                    c.isDebt
                        ? tr(
                            'সিস্টেম ক্যাটাগরি · ${dg(counts[c.id] ?? 0)}টি এন্ট্রি',
                            'System category · ${dg(counts[c.id] ?? 0)} entries',
                          )
                        : tr(
                            '${dg(counts[c.id] ?? 0)}টি এন্ট্রি',
                            '${dg(counts[c.id] ?? 0)} entries',
                          ),
                  ),
                  onTap: () => showCategoryEditor(context, ref, cat: c),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!c.isDebt)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => deleteCategoryFlow(context, ref, c),
                        ),
                      ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (archived.isNotEmpty)
          SliverToBoxAdapter(
            child: ExpansionTile(
              title: Text(
                tr('আর্কাইভ (${dg(archived.length)})', 'Archived (${dg(archived.length)})'),
              ),
              children: [
                for (final c in archived)
                  ListTile(
                    leading: CatAvatar.of(c),
                    title: Text(c.name),
                    subtitle: Text(
                      tr(
                        '${dg(counts[c.id] ?? 0)}টি পুরনো এন্ট্রি',
                        '${dg(counts[c.id] ?? 0)} old entries',
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => ref.read(repoProvider).setCategoryArchived(c.id, false),
                      child: Text(tr('ফিরিয়ে আনুন', 'Restore')),
                    ),
                  ),
              ],
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

/// এন্ট্রি আছে এমন ক্যাটাগরি ডিলিট: অন্য ক্যাটাগরিতে সরাবে, নাকি আর্কাইভ করবে
Future<void> deleteCategoryFlow(BuildContext context, WidgetRef ref, Cat c) async {
  final repo = ref.read(repoProvider);
  final n = await repo.countTxnsInCategory(c.id);
  if (!context.mounted) return;
  if (n == 0) {
    if (await confirm(
      context,
      tr('"${c.name}" মুছবেন?', 'Delete "${c.name}"?'),
      ok: tr('মুছুন', 'Delete'),
      danger: true,
    )) {
      await repo.deleteCategory(c.id);
    }
    return;
  }
  final cats = (ref.read(categoriesProvider).value ?? const <Cat>[])
      .where((x) => x.id != c.id && x.kind == c.kind && !x.archived && !x.isDebt)
      .toList();
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('"${c.name}"-এ ${dg(n)}টি এন্ট্রি আছে', '"${c.name}" has ${dg(n)} entries')),
      content: Text(
        tr('পুরনো হিসাব নষ্ট না করতে কী করবেন?', 'What should happen so old records stay intact?'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল', 'Cancel'))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'archive'),
          child: Text(tr('আর্কাইভ করুন', 'Archive')),
        ),
        if (cats.isNotEmpty)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'move'),
            child: Text(tr('অন্যটিতে সরান', 'Move to another')),
          ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (choice == 'archive') {
    await repo.setCategoryArchived(c.id, true);
    if (context.mounted) {
      toast(
        context,
        tr(
          'আর্কাইভ হয়েছে — এন্ট্রিগুলো আগের মতোই থাকল',
          'Archived — the entries are kept as they were',
        ),
      );
    }
  } else if (choice == 'move') {
    final target = await showDialog<Cat>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('কোন ক্যাটাগরিতে সরাবেন?', 'Move to which category?')),
        children: [
          for (final x in cats)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, x),
              child: Row(
                children: [CatAvatar.of(x, size: 32), const SizedBox(width: 10), Text(x.name)],
              ),
            ),
        ],
      ),
    );
    if (target == null) return;
    await repo.deleteCategory(c.id, moveTo: target.id);
    if (context.mounted) {
      toast(
        context,
        tr(
          '${dg(n)}টি এন্ট্রি "${target.name}"-এ সরানো হয়েছে',
          '${dg(n)} entries moved to "${target.name}"',
        ),
      );
    }
  }
}
