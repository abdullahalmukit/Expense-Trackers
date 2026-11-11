import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../entry/entry_sheet.dart';
import 'common.dart';

/// চার্টের কোনো অংশে ট্যাপ করলে সেই অংশের এন্ট্রিগুলো
Future<void> showTxnListSheet(
  BuildContext context,
  String title,
  bool Function(Txn) filter,
) {
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
                      '${dg(list.length)}টি এন্ট্রি'
                      '${exp > 0 ? ' · খরচ ${money(exp)}' : ''}'
                      '${inc > 0 ? ' · জমা ${money(inc)}' : ''}',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('কোনো এন্ট্রি নেই'))
                    : ListView.builder(
                        controller: controller,
                        itemCount: list.length,
                        itemBuilder: (context, i) => TxnTile(
                          txn: list[i],
                          fin: fin,
                          showDate: true,
                          onTap: () => showEntrySheet(context, edit: list[i]),
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
