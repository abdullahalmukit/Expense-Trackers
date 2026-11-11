import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../entry/entry_sheet.dart';
import '../entry/txn_details.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

class HistoryFilter {
  final int? type;
  final Set<int> categories;
  final Set<int> persons;
  final int? minAmount;
  final int? maxAmount;
  final DateRange? range;
  final bool debtOnly;
  const HistoryFilter({
    this.type,
    this.categories = const {},
    this.persons = const {},
    this.minAmount,
    this.maxAmount,
    this.range,
    this.debtOnly = false,
  });

  bool get active =>
      type != null ||
      categories.isNotEmpty ||
      persons.isNotEmpty ||
      minAmount != null ||
      maxAmount != null ||
      range != null ||
      debtOnly;

  int get count => [
    type != null,
    categories.isNotEmpty,
    persons.isNotEmpty,
    minAmount != null || maxAmount != null,
    range != null,
    debtOnly,
  ].where((b) => b).length;

  bool matches(Txn t) {
    if (type != null && t.type != type) return false;
    if (categories.isNotEmpty && !categories.contains(t.categoryId)) return false;
    if (persons.isNotEmpty && !persons.contains(t.personId)) return false;
    if (minAmount != null && t.amount < minAmount!) return false;
    if (maxAmount != null && t.amount > maxAmount!) return false;
    if (range != null && !range!.contains(t.occurredAt)) return false;
    if (debtOnly && t.debtAction == null) return false;
    return true;
  }
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  bool _searching = false;
  bool _heatmap = false;
  int? _day;
  HistoryFilter _filter = HistoryFilter();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesQuery(Txn t, FinanceData fin, String q) {
    if (q.isEmpty) return true;
    final query = toEnDigits(q.toLowerCase());
    final cat = fin.catById[t.categoryId]?.name.toLowerCase() ?? '';
    final person = t.personId == null ? '' : (fin.personById[t.personId]?.name.toLowerCase() ?? '');
    final amt = paisaToPlain(t.amount);
    return t.note.toLowerCase().contains(query) ||
        t.purpose.toLowerCase().contains(query) ||
        cat.contains(query) ||
        person.contains(query) ||
        amt.contains(query) ||
        (t.debtAction != null && DebtAction.fullLabel(t.debtAction!).contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final fin = ref.watch(financeProvider);
    final month = ref.watch(selectedMonthProvider);
    final q = _search.text.trim();
    final usingRange = _filter.range != null || (q.isNotEmpty);
    final monthRange = DateRange.month(month);

    var list = fin.txns.where((t) => _filter.matches(t) && _matchesQuery(t, fin, q));
    if (!usingRange) list = list.where((t) => monthRange.contains(t.occurredAt));
    if (_day != null && !usingRange) list = list.where((t) => t.occurredAt.day == _day);
    final items = list.toList();

    // দিন অনুযায়ী গ্রুপ
    final groups = <DateTime, List<Txn>>{};
    for (final t in items) {
      groups.putIfAbsent(dayStart(t.occurredAt), () => []).add(t);
    }
    final inc = fin.sumOf(items, TxType.income);
    final exp = fin.sumOf(items, TxType.expense);

    final rows = <Widget>[];
    groups.forEach((day, txns) {
      final dExp = fin.sumOf(txns, TxType.expense);
      final dInc = fin.sumOf(txns, TxType.income);
      rows.add(
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(relativeDayLabel(day), style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .5),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      if (dInc > 0)
                        Text(
                          '+${money(dInc)}  ',
                          style: TextStyle(
                            color: AppColors.income,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (dExp > 0)
                        Text(
                          '-${money(dExp)}',
                          style: TextStyle(
                            color: AppColors.expense,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      for (final t in txns) {
        rows.add(
          TxnTile(
            key: ValueKey(t.id),
            txn: t,
            fin: fin,
            showDate: usingRange,
            onTap: () => showTxnDetails(context, t),
            onEdit: () => showEntrySheet(context, edit: t),
            onDelete: () => deleteTxnWithUndo(context, ref, t),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: tr('বিবরণ, ক্যাটাগরি, নাম, টাকা…', 'Note, category, name, amount…'),
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(tr('হিস্টোরি', 'History')),
        actions: [
          IconButton(
            tooltip: tr('সার্চ', 'Search'),
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
          IconButton(
            tooltip: tr('ক্যালেন্ডার', 'Calendar'),
            icon: Icon(_heatmap ? Icons.calendar_month : Icons.calendar_month_outlined),
            onPressed: () => setState(() => _heatmap = !_heatmap),
          ),
          IconButton(
            tooltip: tr('ফিল্টার', 'Filter'),
            icon: Badge(
              isLabelVisible: _filter.active,
              label: Text(dg(_filter.count)),
              child: Icon(Icons.filter_list),
            ),
            onPressed: () async {
              final f = await showFilterSheet(context, ref, _filter);
              if (f != null) setState(() => _filter = f);
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (!usingRange) const MonthSwitcher(),
                if (usingRange && _filter.range != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: InputChip(
                      label: Text(_filter.range!.label),
                      onDeleted: () => setState(
                        () => _filter = HistoryFilter(
                          type: _filter.type,
                          categories: _filter.categories,
                          persons: _filter.persons,
                          minAmount: _filter.minAmount,
                          maxAmount: _filter.maxAmount,
                          debtOnly: _filter.debtOnly,
                        ),
                      ),
                    ),
                  ),
                if (_heatmap && !usingRange)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SectionCard(
                      title: tr('কোন দিন কত খরচ', 'Spending by day'),
                      trailing: _day == null
                          ? null
                          : TextButton(
                              onPressed: () => setState(() => _day = null),
                              child: Text(tr('${dg(_day!)} তারিখ ✕', 'Day ${dg(_day!)} ✕')),
                            ),
                      child: CalendarHeatmap(
                        month: month,
                        values: fin.dailyTotals(monthRange, TxType.expense),
                        selectedDay: _day,
                        onTapDay: (d) => setState(() => _day = _day == d.day ? null : d.day),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('${dg(items.length)}টি এন্ট্রি', '${dg(items.length)} entries'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .62,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            children: [
                              Text(
                                tr('জমা ', 'In '),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 12,
                                ),
                              ),
                              MoneyText(inc, type: TxType.income),
                              const SizedBox(width: 12),
                              Text(
                                tr('খরচ ', 'Out '),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 12,
                                ),
                              ),
                              MoneyText(exp, type: TxType.expense),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                emoji: q.isNotEmpty || _filter.active ? '🔍' : '📭',
                title: q.isNotEmpty || _filter.active
                    ? tr('কিছু পাওয়া যায়নি', 'Nothing found')
                    : tr('এ মাসে কোনো এন্ট্রি নেই', 'No entries this month'),
                actionLabel: q.isEmpty && !_filter.active
                    ? tr('এন্ট্রি যোগ করুন', 'Add an entry')
                    : null,
                onAction: () => showEntrySheet(context),
              ),
            )
          else
            SliverList.list(children: [...rows, const SizedBox(height: 120)]),
        ],
      ),
    );
  }
}

Future<HistoryFilter?> showFilterSheet(BuildContext context, WidgetRef ref, HistoryFilter current) {
  return showModalBottomSheet<HistoryFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FilterSheet(current),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet(this.current);
  final HistoryFilter current;
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late int? _type = widget.current.type;
  late final Set<int> _cats = {...widget.current.categories};
  late final Set<int> _persons = {...widget.current.persons};
  late final _min = TextEditingController(
    text: widget.current.minAmount == null ? '' : paisaToPlain(widget.current.minAmount!),
  );
  late final _max = TextEditingController(
    text: widget.current.maxAmount == null ? '' : paisaToPlain(widget.current.maxAmount!),
  );
  late DateRange? _range = widget.current.range;
  late bool _debtOnly = widget.current.debtOnly;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fin = ref.watch(financeProvider);
    final cats = fin.cats.where((c) => _type == null || c.kind == _type).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      maxChildSize: .95,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Text(tr('ফিল্টার', 'Filter'), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Text(tr('ধরন', 'Type')),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(tr('সব', 'All')),
                        selected: _type == null,
                        onSelected: (_) => setState(() => _type = null),
                      ),
                      ChoiceChip(
                        label: Text(tr('খরচ', 'Expense')),
                        selected: _type == 0,
                        onSelected: (_) => setState(() => _type = 0),
                      ),
                      ChoiceChip(
                        label: Text(tr('জমা', 'Income')),
                        selected: _type == 1,
                        onSelected: (_) => setState(() => _type = 1),
                      ),
                      FilterChip(
                        label: Text(tr('শুধু ধার', 'Debts only')),
                        selected: _debtOnly,
                        onSelected: (v) => setState(() => _debtOnly = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(tr('ক্যাটাগরি', 'Categories')),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      for (final c in cats)
                        FilterChip(
                          label: Text(
                            tr(
                              '${c.emoji} ${c.name}${c.archived ? ' (আর্কাইভ)' : ''}',
                              '${c.emoji} ${c.name}${c.archived ? ' (archived)' : ''}',
                            ),
                          ),
                          selected: _cats.contains(c.id),
                          onSelected: (v) =>
                              setState(() => v ? _cats.add(c.id) : _cats.remove(c.id)),
                        ),
                    ],
                  ),
                  if (fin.persons.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(tr('ব্যক্তি', 'People')),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        for (final p in fin.persons)
                          FilterChip(
                            label: Text(p.name),
                            selected: _persons.contains(p.id),
                            onSelected: (v) =>
                                setState(() => v ? _persons.add(p.id) : _persons.remove(p.id)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(tr('টাকার রেঞ্জ', 'Amount range')),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _min,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: tr('সর্বনিম্ন ৳', 'Min ৳')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _max,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: tr('সর্বোচ্চ ৳', 'Max ৳')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(tr('তারিখ', 'Date')),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          _range?.label ??
                              tr(
                                'তারিখের পরিসর বাছুন (নইলে নির্বাচিত মাস)',
                                'Pick a date range (otherwise the selected month)',
                              ),
                        ),
                        onPressed: () async {
                          final r = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: _range == null
                                ? null
                                : DateTimeRange(
                                    start: _range!.start,
                                    end: _range!.end.subtract(const Duration(days: 1)),
                                  ),
                          );
                          if (r != null) {
                            setState(
                              () => _range = DateRange(
                                dayStart(r.start),
                                dayStart(r.end).add(const Duration(days: 1)),
                              ),
                            );
                          }
                        },
                      ),
                      if (_range != null)
                        ActionChip(
                          label: Text(tr('বাদ দিন', 'Clear')),
                          onPressed: () => setState(() => _range = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, const HistoryFilter()),
                        child: Text(tr('সব মুছুন', 'Reset')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          HistoryFilter(
                            type: _type,
                            categories: _cats,
                            persons: _persons,
                            minAmount: parseMoney(_min.text),
                            maxAmount: parseMoney(_max.text),
                            range: _range,
                            debtOnly: _debtOnly,
                          ),
                        ),
                        child: Text(tr('প্রয়োগ করুন', 'Apply')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
