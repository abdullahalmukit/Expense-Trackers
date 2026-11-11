import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../entry/entry_sheet.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'person_screen.dart';

class DebtScreen extends ConsumerWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(financeProvider);
    final debts = fin.debts();
    final active = debts.where((d) => !d.settled).toList();
    final settled = debts.where((d) => d.settled).toList();
    final payable = active.fold(0, (s, d) => s + (d.payable > 0 ? d.payable : 0));
    final receivable = active.fold(0, (s, d) => s + (d.receivable > 0 ? d.receivable : 0));

    void open(int personId) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PersonScreen(personId: personId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ধার'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'নতুন ধার',
            onSelected: (a) => showEntrySheet(context, debtAction: a),
            itemBuilder: (_) => [
              for (final a in const [DebtAction.borrow, DebtAction.lend])
                PopupMenuItem(value: a, child: Text(DebtAction.fullLabel(a))),
            ],
          ),
        ],
      ),
      body: debts.isEmpty
          ? EmptyState(
              emoji: '🤝',
              title: 'কোনো ধারের হিসাব নেই',
              subtitle: 'এন্ট্রিতে \'ধার\' টাইল বাছলে কার সাথে কত দেনা-পাওনা — সব এখানে দেখাবে।',
              actionLabel: 'ধার যোগ করুন',
              onAction: () => showEntrySheet(context, debtAction: DebtAction.borrow),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              children: [
                Row(
                  children: [
                    _TotalCard(
                      label: 'আমি দেব',
                      amount: payable,
                      icon: Icons.call_made,
                      sub: '${dg(active.where((d) => d.payable > 0).length)} জনকে',
                    ),
                    const SizedBox(width: 10),
                    _TotalCard(
                      label: 'আমি পাব',
                      amount: receivable,
                      icon: Icons.call_received,
                      sub: '${dg(active.where((d) => d.receivable > 0).length)} জনের কাছে',
                    ),
                  ],
                ),
                if (active.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'কার কাছে কত বাকি',
                    child: HBarList(
                      onTap: open,
                      items: [
                        for (final d in active) ...[
                          if (d.payable > 0) HBarItem(d.person.id, d.person.name, d.payable, AppColors.expense),
                          if (d.receivable > 0) HBarItem(d.person.id, d.person.name, d.receivable, AppColors.income),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      children: [
                        const ColorDot(AppColors.expense),
                        const Text(' আমি দেব   ', style: TextStyle(fontSize: 11)),
                        const ColorDot(AppColors.income),
                        const Text(' আমি পাব', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (active.isNotEmpty)
                  SectionCard(
                    title: 'চলমান',
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                    child: Column(children: [for (final d in active) _PersonTile(d: d, onTap: () => open(d.person.id))]),
                  ),
                if (settled.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ExpansionTile(
                      shape: const Border(),
                      title: Text('মীমাংসিত (${dg(settled.length)})'),
                      leading: const Icon(Icons.verified_outlined, color: AppColors.income),
                      children: [for (final d in settled) _PersonTile(d: d, onTap: () => open(d.person.id))],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.amount, required this.icon, required this.sub});
  final String label;
  final int amount;
  final IconData icon;
  final String sub;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.debt.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.debt.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.debt),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              money(amount),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.debt),
            ),
          ),
          Text(sub, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    ),
  );
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.d, required this.onTap});
  final PersonDebt d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (d.borrowed > 0) lines.add('নিয়েছি ${money(d.borrowed)} · শোধ ${money(d.repaid)}');
    if (d.lent > 0) lines.add('দিয়েছি ${money(d.lent)} · ফেরত ${money(d.collected)}');
    if (d.nextDue != null) lines.add('⏰ ${dayLabel(d.nextDue!)}');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.debt.withValues(alpha: .15),
        child: Text(
          d.person.name.characters.first,
          style: const TextStyle(color: AppColors.debt, fontWeight: FontWeight.w800),
        ),
      ),
      title: Text(d.person.name),
      subtitle: Text(lines.join('\n'), style: const TextStyle(fontSize: 12)),
      isThreeLine: lines.length > 1,
      trailing: d.settled
          ? const Icon(Icons.check_circle, color: AppColors.income)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (d.payable > 0)
                  Text('দেব ${money(d.payable)}', style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w800)),
                if (d.receivable > 0)
                  Text('পাব ${money(d.receivable)}', style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w800)),
              ],
            ),
    );
  }
}
