import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../manage/tags_screen.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// সব সময়ের হিসাব
class OverviewTab extends ConsumerStatefulWidget {
  const OverviewTab({super.key});
  @override
  ConsumerState<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<OverviewTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final fin = ref.watch(financeProvider);
    final withDebt = ref.watch(appSettingsProvider).statsIncludeDebt;
    if (fin.txns.isEmpty) {
      return const EmptyState(emoji: '📈', title: 'এন্ট্রি যোগ করলে এখানে সব সময়ের হিসাব দেখাবে');
    }
    final series = fin.monthlySeries(includeDebt: withDebt);
    final last12 = series.length > 12 ? series.sublist(series.length - 12) : series;
    final allInc = series.fold(0, (s, m) => s + m.income);
    final allExp = series.fold(0, (s, m) => s + m.expense);
    final first = fin.txns.last.occurredAt;
    final totalDays = math.max(1, DateTime.now().difference(dayStart(first)).inDays + 1);
    final realExp = fin.txns
        .where((t) => t.type == TxType.expense && t.debtAction == null)
        .fold(0, (s, t) => s + t.amount);
    final allRange = DateRange(DateTime(1970), DateTime(3000));
    final topCats = fin.categoryTotals(allRange, TxType.expense, includeDebt: false).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = series.isEmpty ? null : series.reduce((a, b) => a.saving >= b.saving ? a : b);
    final worst = series.isEmpty ? null : series.reduce((a, b) => a.expense >= b.expense ? a : b);
    final tags = fin.tagTotals();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                StatLine('বর্তমান মোট ব্যালেন্স', money(fin.currentBalance), bold: true),
                const Divider(),
                StatLine('সব সময়ের মোট জমা', money(allInc), color: AppColors.income),
                StatLine('সব সময়ের মোট খরচ', money(allExp), color: AppColors.expense),
                StatLine('গড় দৈনিক খরচ (ধার ছাড়া)', money((realExp / totalDays).round())),
                StatLine('গড় মাসিক খরচ', money((allExp / math.max(1, series.length)).round())),
                const Divider(),
                StatLine('মোট বাকি ধার — আমি দেব', money(fin.totalPayable), color: AppColors.debt),
                StatLine('মোট বাকি ধার — আমি পাব', money(fin.totalReceivable), color: AppColors.debt),
                if (best != null) ...[
                  const Divider(),
                  StatLine('সবচেয়ে বেশি সঞ্চয়', '${monthLabel(best.month)} · ${money(best.saving)}'),
                  StatLine('সবচেয়ে বেশি খরচ', '${monthLabel(worst!.month)} · ${money(worst.expense)}'),
                ],
                StatLine('হিসাব শুরু', dayLabel(first, withYear: true)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'মাসিক ট্রেন্ড',
          child: TrendChart(
            series: series,
            onTapMonth: (m) {
              ref.read(selectedMonthProvider.notifier).set(m);
              ref.read(tabIndexProvider.notifier).set(0);
            },
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'প্রতি মাসে ক্যাটাগরির ভাগ',
          child: Column(
            children: [
              StackedMonthChart(
                months: [for (final m in last12) m.month],
                data: [
                  for (final m in last12)
                    fin.categoryTotals(DateRange.month(m.month), TxType.expense, includeDebt: withDebt),
                ],
                colors: {for (final c in fin.cats) c.id: Color(c.color)},
                onTapMonth: (m) {
                  ref.read(selectedMonthProvider.notifier).set(m);
                  ref.read(tabIndexProvider.notifier).set(1);
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  for (final e in topCats.take(8))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ColorDot(Color(fin.catById[e.key]?.color ?? 0xFF9E9E9E)),
                        const SizedBox(width: 4),
                        Text(fin.catById[e.key]?.name ?? '?', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'সবচেয়ে বেশি খরচের ক্যাটাগরি',
          child: HBarList(
            items: [
              for (final e in topCats.take(8))
                HBarItem(
                  e.key,
                  '${fin.catById[e.key]?.emoji ?? ''} ${fin.catById[e.key]?.name ?? '?'}',
                  e.value,
                  Color(fin.catById[e.key]?.color ?? 0xFF9E9E9E),
                ),
            ],
          ),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'ট্যাগ',
            trailing: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TagsScreen())),
              child: const Text('সব'),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final e in (tags.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(8))
                  Chip(label: Text('${e.key} · ${money(e.value)}')),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
