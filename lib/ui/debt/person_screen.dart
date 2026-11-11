import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../entry/entry_sheet.dart';
import '../entry/txn_details.dart';
import '../manage/persons_screen.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

/// একজন ব্যক্তির পুরো ধারের হিস্টোরি — সেখান থেকেই 'শোধ করুন' বা 'ফেরত পেলাম'
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId});
  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(financeProvider);
    final person = fin.personById[personId];
    if (person == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(tr('ব্যক্তি পাওয়া যায়নি', 'Person not found'))),
      );
    }
    final d = fin.debts().where((x) => x.person.id == personId).firstOrNull ?? PersonDebt(person);
    final rows = fin.ledger(personId);
    final payRows = rows
        .where((r) => r.txn.debtAction == DebtAction.borrow || r.txn.debtAction == DebtAction.repay)
        .toList();
    final recRows = rows
        .where((r) => r.txn.debtAction == DebtAction.lend || r.txn.debtAction == DebtAction.collect)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          IconButton(
            tooltip: tr('এডিট', 'Edit'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showPersonEditor(context, ref, person),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (person.phone.isNotEmpty || person.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                [
                  if (person.phone.isNotEmpty) '📞 ${dg(person.phone)}',
                  if (person.note.isNotEmpty) person.note,
                ].join(' · '),
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          if (d.settled && rows.isNotEmpty)
            Card(
              color: AppColors.income.withValues(alpha: .12),
              child: ListTile(
                leading: Icon(Icons.verified, color: AppColors.income),
                title: Text(tr('সব মীমাংসিত', 'All settled')),
                subtitle: Text(
                  tr(
                    'কোনো দেনা-পাওনা বাকি নেই — হিস্টোরি নিচে থাকল',
                    'Nothing outstanding — history is kept below',
                  ),
                ),
              ),
            ),
          if (d.borrowed > 0 || payRows.isNotEmpty)
            _Side(
              title: tr('আমি নিয়েছি', 'I borrowed'),
              total: d.borrowed,
              done: d.repaid,
              doneLabel: tr('শোধ করেছি', 'Repaid'),
              remaining: d.payable,
              remainingLabel: tr('বাকি (আমি দেব)', 'Remaining (I owe)'),
              color: AppColors.expense,
              rows: payRows,
              fin: fin,
              actionLabel: tr('শোধ করুন', 'Repay'),
              onAction: d.payable > 0
                  ? () => showEntrySheet(
                      context,
                      debtAction: DebtAction.repay,
                      personId: personId,
                      amount: d.payable,
                    )
                  : null,
              onAgain: () =>
                  showEntrySheet(context, debtAction: DebtAction.borrow, personId: personId),
              againLabel: tr('আরও নিলাম', 'Borrow more'),
            ),
          if (d.lent > 0 || recRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Side(
              title: tr('আমি দিয়েছি', 'I lent'),
              total: d.lent,
              done: d.collected,
              doneLabel: tr('ফেরত পেয়েছি', 'Got back'),
              remaining: d.receivable,
              remainingLabel: tr('পাওনা বাকি (আমি পাব)', 'Remaining (owed to me)'),
              color: AppColors.income,
              rows: recRows,
              fin: fin,
              actionLabel: tr('ফেরত পেলাম', 'Got back'),
              onAction: d.receivable > 0
                  ? () => showEntrySheet(
                      context,
                      debtAction: DebtAction.collect,
                      personId: personId,
                      amount: d.receivable,
                    )
                  : null,
              onAgain: () =>
                  showEntrySheet(context, debtAction: DebtAction.lend, personId: personId),
              againLabel: tr('আরও দিলাম', 'Lend more'),
            ),
          ],
          if (rows.isEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        showEntrySheet(context, debtAction: DebtAction.borrow, personId: personId),
                    child: Text(tr('ধার নিলাম', 'Borrowed')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        showEntrySheet(context, debtAction: DebtAction.lend, personId: personId),
                    child: Text(tr('ধার দিলাম', 'Lent')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.title,
    required this.total,
    required this.done,
    required this.doneLabel,
    required this.remaining,
    required this.remainingLabel,
    required this.color,
    required this.rows,
    required this.fin,
    required this.actionLabel,
    required this.onAction,
    required this.onAgain,
    required this.againLabel,
  });
  final String title;
  final int total;
  final int done;
  final String doneLabel;
  final int remaining;
  final String remainingLabel;
  final Color color;
  final List<LedgerRow> rows;
  final FinanceData fin;
  final String actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onAgain;
  final String againLabel;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatLine(tr('মোট', 'Total'), money(total)),
          StatLine(doneLabel, money(done)),
          StatLine(remainingLabel, money(remaining), color: AppColors.debt, bold: true),
          if (total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (done / total).clamp(0, 1),
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: .15),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.debt),
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onAgain, child: Text(againLabel)),
            ],
          ),
          const SizedBox(height: 12),
          // টেবিল: তারিখ · কী হলো · টাকা · বাকি (নতুনটা উপরে)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 12, color: outline, fontWeight: FontWeight.w700),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(tr('তারিখ', 'Date'))),
                  Expanded(flex: 3, child: Text(tr('কী হলো', 'What'))),
                  Expanded(flex: 3, child: Text(tr('টাকা', 'Amount'), textAlign: TextAlign.end)),
                  Expanded(flex: 3, child: Text(tr('বাকি', 'Left'), textAlign: TextAlign.end)),
                ],
              ),
            ),
          ),
          for (final r in rows)
            InkWell(
              onTap: () => showTxnDetails(context, r.txn),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(dayLabel(r.txn.occurredAt), style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        DebtAction.label(r.txn.debtAction!),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        money(r.txn.amount),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        money(r.remaining),
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: AppColors.debt, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (rows.any((r) => r.txn.note.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr('সারিতে ট্যাপ করলে বিস্তারিত', 'Tap a row for details'),
                style: TextStyle(fontSize: 11, color: outline),
              ),
            ),
        ],
      ),
    );
  }
}
