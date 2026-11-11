import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/txn_list_sheet.dart';
import 'overview_screen.dart';

enum RangeKind { month, three, six, year, custom }

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _StatsAppBar(),
        body: TabBarView(children: [_StatsTab(), OverviewTab()]),
      ),
    );
  }
}

class _StatsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StatsAppBar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);
  @override
  Widget build(BuildContext context) => AppBar(
    title: const Text('পরিসংখ্যান'),
    bottom: const TabBar(
      tabs: [Tab(text: 'পরিসংখ্যান'), Tab(text: 'ওভারভিউ')],
    ),
  );
}

class _StatsTab extends ConsumerStatefulWidget {
  const _StatsTab();
  @override
  ConsumerState<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<_StatsTab> with AutomaticKeepAliveClientMixin {
  RangeKind _kind = RangeKind.month;
  DateRange? _custom;
  int _donutType = TxType.expense;

  @override
  bool get wantKeepAlive => true;

  DateRange _range(DateTime month) => switch (_kind) {
    RangeKind.month => DateRange.month(month),
    RangeKind.three => DateRange.lastMonths(month, 3),
    RangeKind.six => DateRange.lastMonths(month, 6),
    RangeKind.year => DateRange.lastMonths(month, 12),
    RangeKind.custom => _custom ?? DateRange.month(month),
  };

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _custom == null
          ? DateTimeRange(start: monthStart(now), end: now)
          : DateTimeRange(start: _custom!.start, end: _custom!.end.subtract(const Duration(days: 1))),
    );
    if (r != null) {
      setState(() {
        _kind = RangeKind.custom;
        _custom = DateRange(dayStart(r.start), dayStart(r.end).add(const Duration(days: 1)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final fin = ref.watch(financeProvider);
    final settings = ref.watch(appSettingsProvider);
    final withDebt = settings.statsIncludeDebt;
    final month = ref.watch(selectedMonthProvider);
    final r = _range(month);
    final list = fin.inRange(r, includeDebt: withDebt).toList();
    final inc = fin.sumOf(list, TxType.income);
    final exp = fin.sumOf(list, TxType.expense);
    final days = r.days;
    final now = DateTime.now();
    final elapsedDays = r.contains(now) ? now.difference(r.start).inDays + 1 : days;
    bool inR(t) => r.contains(t.occurredAt) && (withDebt || t.debtAction == null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (k, label) in const [
                (RangeKind.month, 'এই মাস'),
                (RangeKind.three, '৩ মাস'),
                (RangeKind.six, '৬ মাস'),
                (RangeKind.year, 'বছর'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
                ),
              ChoiceChip(
                avatar: const Icon(Icons.date_range, size: 16),
                label: const Text('কাস্টম'),
                selected: _kind == RangeKind.custom,
                onSelected: (_) => _pickCustom(),
              ),
            ],
          ),
        ),
        if (_kind != RangeKind.custom) const Center(child: MonthSwitcher(compact: true)),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(r.label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              ),
              const Text('ধার সহ'),
              Switch(
                value: withDebt,
                onChanged: (v) => ref.read(repoProvider).setSetting('stats_debt', v ? '1' : '0'),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _Kpi('মোট জমা', money(inc), AppColors.income),
            const SizedBox(width: 8),
            _Kpi('মোট খরচ', money(exp), AppColors.expense),
            const SizedBox(width: 8),
            _Kpi('সঞ্চয়', money(inc - exp), AppColors.brand),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Kpi('গড় দৈনিক খরচ', money((exp / elapsedDays.clamp(1, 100000)).round()), AppColors.expense),
            const SizedBox(width: 8),
            _Kpi('এন্ট্রি', dg(list.length), Theme.of(context).colorScheme.primary),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'ক্যাটাগরিভিত্তিক ভাগ',
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
          child: Column(
            children: [
              DonutChart(
                maxLegend: 8,
                slices: [
                  for (final e in fin.categoryTotals(r, _donutType, includeDebt: withDebt).entries)
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
                  '${fin.catById[id]?.emoji ?? ''} ${fin.catById[id]?.name ?? ''} · ${r.label}',
                  (t) => t.categoryId == id && inR(t),
                ),
              ),
              const Divider(height: 24),
              _CategoryTable(fin: fin, range: r, type: _donutType, withDebt: withDebt),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'দৈনিক খরচ',
          child: DailyBarChart(
            values: fin.dailyTotals(r, TxType.expense, includeDebt: withDebt),
            start: r.start,
            onTapDay: (i) {
              final d = r.start.add(Duration(days: i));
              showTxnListSheet(context, relativeDayLabel(d), (t) => sameDay(t.occurredAt, d) && inR(t));
            },
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'ক্রমযোজিত খরচ · ${monthLabel(monthStart(r.end.subtract(const Duration(days: 1))))}',
          child: Builder(builder: (context) {
            final m = monthStart(r.end.subtract(const Duration(days: 1)));
            return CumulativeChart(
              month: m,
              current: fin.cumulative(m, TxType.expense, includeDebt: withDebt),
              lastMonth: fin.cumulative(prevMonth(m), TxType.expense, includeDebt: withDebt),
              budget: fin.budgetFor(m, 0),
            );
          }),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'কখন বড় খরচ হয়',
          child: TimeScatterChart(
            points: [
              for (final t in list.where((t) => t.type == TxType.expense))
                ScatterPoint(
                  t.id,
                  t.occurredAt.hour + t.occurredAt.minute / 60,
                  t.amount,
                  Color(fin.catById[t.categoryId]?.color ?? 0xFF9E9E9E),
                ),
            ],
            onTap: (id) => showTxnListSheet(context, 'এন্ট্রি', (t) => t.id == id),
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryTable extends StatelessWidget {
  const _CategoryTable({required this.fin, required this.range, required this.type, required this.withDebt});
  final FinanceData fin;
  final DateRange range;
  final int type;
  final bool withDebt;

  @override
  Widget build(BuildContext context) {
    final totals = fin.categoryTotals(range, type, includeDebt: withDebt).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sum = totals.fold(0, (s, e) => s + e.value);
    if (sum == 0) return const SizedBox.shrink();
    return Column(
      children: [
        for (final e in totals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CatAvatar.of(fin.catById[e.key], size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fin.catById[e.key]?.name ?? '?'),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: e.value / sum,
                          minHeight: 5,
                          color: Color(fin.catById[e.key]?.color ?? 0xFF9E9E9E),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(percent(e.value / sum * 100), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
