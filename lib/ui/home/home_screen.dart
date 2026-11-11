import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../entry/entry_sheet.dart';
import '../manage/goals_screen.dart';
import '../manage/budgets_screen.dart';
import '../manage/wallets_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import '../widgets/txn_list_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _donutType = TxType.expense;

  @override
  Widget build(BuildContext context) {
    final fin = ref.watch(financeProvider);
    final month = ref.watch(selectedMonthProvider);
    final goals = ref.watch(goalsProvider).value ?? const [];
    final summary = fin.monthSummary(month);
    final r = DateRange.month(month);
    final monthTxns = fin.inRange(r).toList();
    final budgets = fin.budgetStatuses(month);
    final insights = fin.insights(month);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            AppLogo(size: 32),
            SizedBox(width: 10),
            Text('টাকার খাতা'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'সেটিংস',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: fin.txns.isEmpty && fin.wallets.every((w) => w.openingBalance == 0)
          ? EmptyState(
              title: 'স্বাগতম! আপনার হিসাবের খাতা এখনও ফাঁকা',
              subtitle: 'খরচ, জমা বা ধার — যেকোনো কিছু দিয়ে শুরু করুন। সব ডাটা শুধু এই ফোনেই থাকবে।',
              actionLabel: 'প্রথম এন্ট্রি যোগ করুন',
              onAction: () => showEntrySheet(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              children: [
                const Center(child: MonthSwitcher()),
                const SizedBox(height: 8),
                _SummaryCard(summary: summary),
                if (fin.wallets.where((w) => !w.archived).length > 1) ...[
                  const SizedBox(height: 12),
                  _WalletStrip(),
                ],
                if (insights.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Insights(insights),
                ],
                const SizedBox(height: 12),
                SectionCard(
                  title: 'মাসে এ পর্যন্ত খরচ',
                  child: CumulativeChart(
                    month: month,
                    current: fin.cumulative(month, TxType.expense),
                    lastMonth: fin.cumulative(prevMonth(month), TxType.expense),
                    budget: fin.budgetFor(month, 0),
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'ক্যাটাগরি অনুযায়ী',
                  trailing: SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: const [
                      ButtonSegment(value: TxType.expense, label: Text('খরচ')),
                      ButtonSegment(value: TxType.income, label: Text('জমা')),
                    ],
                    selected: {_donutType},
                    onSelectionChanged: (s) => setState(() => _donutType = s.first),
                  ),
                  child: DonutChart(
                    slices: [
                      for (final e in fin.categoryTotals(r, _donutType).entries)
                        Slice(
                          e.key,
                          fin.catById[e.key]?.name ?? '?',
                          fin.catById[e.key]?.emoji ?? '',
                          e.value,
                          Color(fin.catById[e.key]?.color ?? 0xFF9E9E9E),
                        ),
                    ],
                    onTap: (id) => showTxnListSheet(
                      context,
                      '${fin.catById[id]?.emoji ?? ''} ${fin.catById[id]?.name ?? ''} · ${monthLabel(month)}',
                      (t) => t.categoryId == id && r.contains(t.occurredAt),
                    ),
                  ),
                ),
                if (budgets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'বাজেট',
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                      ),
                      child: const Text('সাজান'),
                    ),
                    child: Column(
                      children: [
                        for (final b in budgets.take(5))
                          BudgetBar(
                            status: b,
                            label: b.categoryId == 0
                                ? '📊 মোট বাজেট'
                                : '${fin.catById[b.categoryId]?.emoji} ${fin.catById[b.categoryId]?.name}',
                          ),
                      ],
                    ),
                  ),
                ],
                if (goals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'সঞ্চয়ের লক্ষ্য',
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GoalsScreen()),
                      ),
                      child: const Text('সব'),
                    ),
                    child: SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [for (final g in goals) GoalRing(goal: g, size: 76)],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SectionCard(
                  title: 'সাম্প্রতিক',
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => ref.read(tabIndexProvider.notifier).set(1),
                      child: const Text('সব দেখুন'),
                    ),
                  ),
                  child: monthTxns.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('এ মাসে এখনও কোনো এন্ট্রি নেই')),
                        )
                      : Column(
                          children: [
                            for (final t in monthTxns.take(6))
                              TxnTile(
                                txn: t,
                                fin: fin,
                                showDate: true,
                                onTap: () => showEntrySheet(context, edit: t),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final dim = white.withValues(alpha: .75);
    Widget stat(String label, int v, Color c, IconData icon) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: c),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: dim, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                money(v),
                style: const TextStyle(color: white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand, Color(0xFF3B4BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.brand.withValues(alpha: .3), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('মাস শেষের ব্যালেন্স', style: TextStyle(color: dim)),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              money(summary.closing),
              style: const TextStyle(color: white, fontSize: 34, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            'শুরুর ব্যালেন্স ${money(summary.opening)} (আগের মাস থেকে)',
            style: TextStyle(color: dim, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('মোট জমা', summary.income, const Color(0xFF8FF0B4), Icons.south_west),
              const SizedBox(width: 10),
              stat('মোট খরচ', summary.expense, const Color(0xFFFFB4A6), Icons.north_east),
            ],
          ),
          if (summary.debtIncome > 0 || summary.debtExpense > 0) ...[
            const SizedBox(height: 10),
            Text(
              'ধার সহ · ধার ছাড়া আসল জমা ${money(summary.realIncome)}, খরচ ${money(summary.realExpense)}',
              style: TextStyle(color: dim, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(financeProvider);
    final bal = fin.walletBalances();
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final w in fin.wallets.where((w) => !w.archived))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletsScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Text(w.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(w.name, style: const TextStyle(fontSize: 12)),
                            Text(money(bal[w.id] ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights(this.items);
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 88,
      child: PageView.builder(
        controller: PageController(viewportFraction: .92),
        padEnds: false,
        itemCount: items.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brandAccent.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.brandAccent.withValues(alpha: .6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    items[i],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurface, height: 1.35),
                  ),
                ),
                if (items.length > 1)
                  Text(
                    '${dg(i + 1)}/${dg(items.length)}',
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.status, required this.label});
  final BudgetStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = status.ratio;
    final c = r >= 1 ? AppColors.expense : (r >= .8 ? Colors.orange : AppColors.income);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(
                '${money(status.spent)} / ${money(status.limit)}',
                style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: math.min(1, r),
              minHeight: 8,
              color: c,
              backgroundColor: c.withValues(alpha: .15),
            ),
          ),
        ],
      ),
    );
  }
}
