import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import '../widgets/txn_list_sheet.dart';
import '../../core/i18n.dart';

/// #ট্যুর — এক ট্যাগের সব ক্যাটাগরির মোট খরচ এক জায়গায়
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(financeProvider);
    final exp = fin.tagTotals();
    final inc = fin.tagTotals(type: TxType.income);
    final tags = fin.allTags.toList()..sort((a, b) => (exp[b] ?? 0).compareTo(exp[a] ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text(tr('ট্যাগ', 'Tags'))),
      body: tags.isEmpty
          ? EmptyState(
              emoji: '#️⃣',
              title: tr('কোনো ট্যাগ নেই', 'No tags'),
              subtitle: tr(
                'এন্ট্রির বিবরণে #ট্যুর এর মতো লিখলে এখানে সব ক্যাটাগরির মোট দেখাবে',
                'Write something like #trip in an entry\'s note to see its total across categories here',
              ),
            )
          : ListView(
              children: [
                for (final t in tags)
                  ListTile(
                    leading: const CircleAvatar(child: Text('#')),
                    title: Text(t),
                    subtitle: Text(
                      tr(
                            '${dg(fin.txns.where((x) => tagsOf(x).contains(t)).length)}টি এন্ট্রি',
                            '${dg(fin.txns.where((x) => tagsOf(x).contains(t)).length)} entries',
                          ) +
                          ((inc[t] ?? 0) > 0
                              ? tr(' · জমা ${money(inc[t]!)}', ' · income ${money(inc[t]!)}')
                              : ''),
                    ),
                    trailing: MoneyText(exp[t] ?? 0, type: TxType.expense),
                    onTap: () => _detail(context, fin, t),
                  ),
              ],
            ),
    );
  }

  void _detail(BuildContext context, FinanceData fin, String tag) {
    showTxnListSheet(context, tag, (x) => tagsOf(x).contains(tag));
  }
}
