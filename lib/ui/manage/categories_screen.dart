import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import 'category_editor.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ক্যাটাগরি'),
          bottom: const TabBar(tabs: [Tab(text: 'খরচ'), Tab(text: 'জমা')]),
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () => showCategoryEditor(
              context,
              ref,
              kind: DefaultTabController.of(context).index,
            ),
            icon: const Icon(Icons.add),
            label: const Text('নতুন'),
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
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text('ধরে রেখে টেনে ক্রম বদলান · ট্যাপ করে এডিট', style: TextStyle(fontSize: 12)),
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
                    c.isDebt ? 'সিস্টেম ক্যাটাগরি · ${dg(counts[c.id] ?? 0)}টি এন্ট্রি' : '${dg(counts[c.id] ?? 0)}টি এন্ট্রি',
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
              title: Text('আর্কাইভ (${dg(archived.length)})'),
              children: [
                for (final c in archived)
                  ListTile(
                    leading: CatAvatar.of(c),
                    title: Text(c.name),
                    subtitle: Text('${dg(counts[c.id] ?? 0)}টি পুরনো এন্ট্রি'),
                    trailing: TextButton(
                      onPressed: () => ref.read(repoProvider).setCategoryArchived(c.id, false),
                      child: const Text('ফিরিয়ে আনুন'),
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
    if (await confirm(context, '"${c.name}" মুছবেন?', ok: 'মুছুন', danger: true)) {
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
      title: Text('"${c.name}"-এ ${dg(n)}টি এন্ট্রি আছে'),
      content: const Text('পুরনো হিসাব নষ্ট না করতে কী করবেন?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'archive'), child: const Text('আর্কাইভ করুন')),
        if (cats.isNotEmpty)
          FilledButton(onPressed: () => Navigator.pop(ctx, 'move'), child: const Text('অন্যটিতে সরান')),
      ],
    ),
  );
  if (!context.mounted) return;
  if (choice == 'archive') {
    await repo.setCategoryArchived(c.id, true);
    if (context.mounted) toast(context, 'আর্কাইভ হয়েছে — এন্ট্রিগুলো আগের মতোই থাকল');
  } else if (choice == 'move') {
    final target = await showDialog<Cat>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('কোন ক্যাটাগরিতে সরাবেন?'),
        children: [
          for (final x in cats)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, x),
              child: Row(children: [CatAvatar.of(x, size: 32), const SizedBox(width: 10), Text(x.name)]),
            ),
        ],
      ),
    );
    if (target == null) return;
    await repo.deleteCategory(c.id, moveTo: target.id);
    if (context.mounted) toast(context, '${dg(n)}টি এন্ট্রি "${target.name}"-এ সরানো হয়েছে');
  }
}
