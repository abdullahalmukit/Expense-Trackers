import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../entry/txn_details.dart';
import 'common.dart';
import '../../core/i18n.dart';

/// চার্টের কোনো অংশে ট্যাপ করলে সেই অংশের এন্ট্রিগুলো
Future<void> showTxnListSheet(BuildContext context, String title, bool Function(Txn) filter) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      maxChildSize: .95,
      builder: (context, controller) => Consumer(
        builder: (context, ref, _) {
          final fin = ref.watch(financeProvider);
          final list = fin.txns.where(filter).toList();
          final inc = fin.sumOf(list, TxType.income);
          final exp = fin.sumOf(list, TxType.expense);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      tr('${dg(list.length)}টি এন্ট্রি', '${dg(list.length)} entries') +
                          (exp > 0 ? tr(' · খরচ ${money(exp)}', ' · spent ${money(exp)}') : '') +
                          (inc > 0 ? tr(' · জমা ${money(inc)}', ' · income ${money(inc)}') : ''),
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(child: Text(tr('কোনো এন্ট্রি নেই', 'No entries')))
                    : ListView.builder(
                        controller: controller,
                        itemCount: list.length,
                        itemBuilder: (context, i) => TxnTile(
                          txn: list[i],
                          fin: fin,
                          showDate: true,
                          onTap: () => showTxnDetails(context, list[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
