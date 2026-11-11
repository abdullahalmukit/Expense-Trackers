import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../home/home_screen.dart';
import '../widgets/common.dart';

/// ক্যাটাগরিভিত্তিক মাসিক সীমা — ৮০% আর ১০০% পার হলে নোটিফিকেশন
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(financeProvider);
    final month = ref.watch(selectedMonthProvider);
    final totals = fin.categoryTotals(DateRange.month(month), TxType.expense);
    final totalSpent = totals.values.fold(0, (s, v) => s + v);
    final cats = fin.cats.where((c) => c.kind == TxType.expense && !c.archived).toList();

    Widget row(int id, String label, Widget leading, int spent) {
      final limit = fin.budgetFor(month, id);
      return ListTile(
        leading: leading,
        title: Text(label),
        subtitle: limit == null
            ? Text('বাজেট নেই · খরচ ${money(spent)}')
            : BudgetBar(status: BudgetStatus(id, limit, spent), label: ''),
        trailing: const Icon(Icons.edit_outlined, size: 20),
        onTap: () => _edit(context, ref, month, id, label, limit),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('মাসিক বাজেট')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 60),
        children: [
          const Center(child: MonthSwitcher()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'যে মাসে সেট করবেন সেই মাস থেকে পরের সব মাসে প্রযোজ্য থাকবে, যতক্ষণ না বদলান।',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
          ),
          row(0, 'মোট বাজেট', const CircleAvatar(child: Text('📊')), totalSpent),
          const Divider(),
          for (final c in cats) row(c.id, c.name, CatAvatar.of(c), totals[c.id] ?? 0),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, DateTime month, int id, String label, int? current) async {
    final c = TextEditingController(text: current == null ? '' : paisaToPlain(current));
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label · ${monthLabel(month)} থেকে'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'মাসিক সীমা ৳'),
        ),
        actions: [
          if (current != null) TextButton(onPressed: () => Navigator.pop(ctx, 'clear'), child: const Text('বাজেট বাদ')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('সেভ')),
        ],
      ),
    );
    final repo = ref.read(repoProvider);
    if (r == 'save') {
      final v = parseMoney(c.text);
      if (v != null && v > 0) await repo.setBudget(month, id, v);
    } else if (r == 'clear') {
      await repo.setBudget(month, id, 0);
    }
  }
}
