import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../domain/finance.dart';
import '../ui/widgets/charts.dart';
import '../ui/widgets/logo.dart';
import '../core/i18n.dart';

/// PDF রিপোর্ট। বাংলা যুক্তাক্ষর ঠিকভাবে দেখাতে প্রতিটি পাতা Flutter দিয়ে আঁকা হয়,
/// তারপর ছবি হিসেবে PDF-এ বসানো হয় — চার্টও হুবহু অ্যাপের মতো।
class PdfReport {
  static const pageSize = Size(595, 842); // A4 (pt)
  static const _rowsPerPage = 26;

  static Future<Uint8List> build(FinanceData fin, DateRange? r) async {
    final txns = (r == null ? [...fin.txns] : fin.inRange(r).toList())
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final months =
        r?.months ??
        (txns.isEmpty
            ? [monthStart(DateTime.now())]
            : DateRange(
                monthStart(txns.first.occurredAt),
                nextMonth(monthStart(txns.last.occurredAt)),
              ).months);

    final pages = <Widget>[];
    var pageNo = 0;
    Widget frame(Widget child) {
      pageNo++;
      return _Page(pageNo: pageNo, child: child);
    }

    if (months.length > 1) {
      pages.add(
        frame(
          _OverviewPage(fin: fin, months: months, label: r?.label ?? tr('সব সময়', 'All time')),
        ),
      );
    }
    for (final m in months) {
      final range = DateRange.month(m);
      final list = txns.where((t) => range.contains(t.occurredAt)).toList();
      if (list.isEmpty && months.length > 1) continue;
      pages.add(frame(_MonthSummaryPage(fin: fin, month: m)));
      for (var i = 0; i < list.length; i += _rowsPerPage) {
        final chunk = list.sublist(i, (i + _rowsPerPage).clamp(0, list.length));
        pages.add(
          frame(_EntriesPage(fin: fin, month: m, rows: chunk, startIndex: i, total: list.length)),
        );
      }
    }
    final debts = fin.debts().where((d) => !d.settled).toList();
    if (debts.isNotEmpty) pages.add(frame(_DebtPage(debts: debts)));

    final doc = pw.Document(
      title: tr('টাকার খাতা রিপোর্ট', 'Takar Khata report'),
      creator: tr('টাকার খাতা', 'Takar Khata'),
    );
    final oldAnim = ChartAnim.duration;
    ChartAnim.duration = Duration.zero;
    try {
      for (final p in pages) {
        final img = await renderToImage(p, pageSize, pixelRatio: 2.2);
        final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final image = pw.RawImage(
          bytes: raw!.buffer.asUint8List(),
          width: img.width,
          height: img.height,
        );
        img.dispose();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
          ),
        );
      }
    } finally {
      ChartAnim.duration = oldAnim;
    }
    return doc.save();
  }
}

/// স্ক্রিনে না দেখিয়েই একটি উইজেটকে ছবিতে আঁকা
Future<ui.Image> renderToImage(Widget widget, Size size, {double pixelRatio = 2}) async {
  final boundary = RenderRepaintBoundary();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size),
      devicePixelRatio: 1,
    ),
  );
  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final theme = buildTheme(Brightness.light);
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: theme,
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(color: Colors.black87),
            child: Material(color: Colors.white, child: widget),
          ),
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);
  buildOwner.buildScope(root);
  buildOwner.finalizeTree();
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  // ট্রি খুলে ফেলা, যাতে State গুলো dispose হয়
  RenderObjectToWidgetAdapter<RenderBox>(container: boundary).attachToRenderTree(buildOwner, root);
  buildOwner.buildScope(root);
  buildOwner.finalizeTree();
  return image;
}

class _Page extends StatelessWidget {
  const _Page({required this.pageNo, required this.child});
  final int pageNo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 26, 32, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AppLogo(size: 26),
            const SizedBox(width: 8),
            Text(
              tr('টাকার খাতা', 'Takar Khata'),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.brand),
            ),
            const Spacer(),
            Text(
              tr(
                'তৈরি: ${dateTimeLabel(DateTime.now())}',
                'Generated: ${dateTimeLabel(DateTime.now())}',
              ),
              style: const TextStyle(fontSize: 9, color: Colors.black54),
            ),
          ],
        ),
        const Divider(height: 14),
        Expanded(child: child),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            tr('পৃষ্ঠা ${dg(pageNo)}', 'Page ${dg(pageNo)}'),
            style: const TextStyle(fontSize: 9, color: Colors.black54),
          ),
        ),
      ],
    ),
  );
}

TextStyle get _h1 =>
    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.brand);
TextStyle get _h2 => const TextStyle(fontSize: 13, fontWeight: FontWeight.w800);

Widget _kv(String k, String v, {Color? color, bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Row(
    children: [
      Expanded(child: Text(k, style: const TextStyle(fontSize: 11))),
      Text(
        v,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    ],
  ),
);

class _MonthSummaryPage extends StatelessWidget {
  const _MonthSummaryPage({required this.fin, required this.month});
  final FinanceData fin;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final s = fin.monthSummary(month);
    final r = DateRange.month(month);
    final cats = fin.categoryTotals(r, TxType.expense).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = cats.fold(0, (x, e) => x + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('মাসিক রিপোর্ট · ${monthLabel(month)}', 'Monthly report · ${monthLabel(month)}'),
          style: _h1,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.brandAccent.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _kv(tr('শুরুর ব্যালেন্স', 'Opening balance'), money(s.opening)),
                    _kv(
                      tr('মোট জমা (ধার সহ)', 'Total income (incl. debt)'),
                      money(s.income),
                      color: AppColors.income,
                    ),
                    _kv(
                      tr('মোট খরচ (ধার সহ)', 'Total expense (incl. debt)'),
                      money(s.expense),
                      color: AppColors.expense,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _kv(tr('ধার ছাড়া আসল জমা', 'Income excl. debt'), money(s.realIncome)),
                    _kv(tr('ধার ছাড়া আসল খরচ', 'Expense excl. debt'), money(s.realExpense)),
                    _kv(
                      tr('মাস শেষের ব্যালেন্স', 'Month-end balance'),
                      money(s.closing),
                      bold: true,
                      color: AppColors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(tr('ক্যাটাগরিভিত্তিক খরচ', 'Spending by category'), style: _h2),
        const SizedBox(height: 6),
        SizedBox(
          height: 150,
          child: DonutChart(
            size: 140,
            maxLegend: 8,
            slices: [
              for (final e in cats)
                Slice(
                  e.key,
                  fin.catById[e.key]?.name ?? '?',
                  fin.catById[e.key]?.emoji ?? '',
                  e.value,
                  Color(fin.catById[e.key]?.color ?? 0xFF9E9E9E),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (cats.isNotEmpty)
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1.4),
              2: FlexColumnWidth(1),
            },
            border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)),
            children: [
              for (final e in cats.take(10))
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '${fin.catById[e.key]?.emoji ?? ''} ${fin.catById[e.key]?.name ?? ''}',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ),
                    Text(
                      money(e.value),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      percent(e.value / total * 100),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ],
                ),
            ],
          ),
        const SizedBox(height: 12),
        Text(tr('দৈনিক খরচ', 'Daily spending'), style: _h2),
        const SizedBox(height: 6),
        DailyBarChart(values: fin.dailyTotals(r, TxType.expense), start: r.start, height: 150),
        const Spacer(),
      ],
    );
  }
}

class _EntriesPage extends StatelessWidget {
  const _EntriesPage({
    required this.fin,
    required this.month,
    required this.rows,
    required this.startIndex,
    required this.total,
  });
  final FinanceData fin;
  final DateTime month;
  final List<Txn> rows;
  final int startIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 10, fontWeight: FontWeight.w800);
    const cell = TextStyle(fontSize: 9.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            '${monthLabel(month)} · এন্ট্রির তালিকা (${dg(startIndex + 1)}–${dg(startIndex + rows.length)} / ${dg(total)})',
            '${monthLabel(month)} · entries (${dg(startIndex + 1)}–${dg(startIndex + rows.length)} / ${dg(total)})',
          ),
          style: _h2,
        ),
        SizedBox(height: 8),
        Table(
          columnWidths: {
            0: FlexColumnWidth(1.6),
            1: FlexColumnWidth(2.2),
            2: FlexColumnWidth(3),
            3: FlexColumnWidth(1.4),
          },
          border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)),
          children: [
            TableRow(
              decoration: BoxDecoration(color: AppColors.brandAccent.withValues(alpha: .35)),
              children: [
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(tr('তারিখ', 'Date'), style: head),
                ),
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(tr('ক্যাটাগরি', 'Category'), style: head),
                ),
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(tr('বিবরণ', 'Note'), style: head),
                ),
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(tr('টাকা', 'Amount'), style: head, textAlign: TextAlign.right),
                ),
              ],
            ),
            for (final t in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      '${dayLabel(t.occurredAt)}\n${timeLabel(t.occurredAt)}',
                      style: cell,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      t.debtAction != null
                          ? '${fin.catById[t.categoryId]?.emoji ?? ''} ${DebtAction.fullLabel(t.debtAction!)}\n${fin.personById[t.personId]?.name ?? ''}'
                          : '${fin.catById[t.categoryId]?.emoji ?? ''} ${fin.catById[t.categoryId]?.name ?? ''}',
                      style: cell,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      [t.note, t.purpose].where((x) => x.isNotEmpty).join(' · '),
                      style: cell,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      money(t.type == TxType.expense ? -t.amount : t.amount, signed: true),
                      textAlign: TextAlign.right,
                      style: cell.copyWith(
                        fontWeight: FontWeight.w800,
                        color: t.debtAction != null ? AppColors.debt : AppColors.forType(t.type),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.fin, required this.months, required this.label});
  final FinanceData fin;
  final List<DateTime> months;
  final String label;

  @override
  Widget build(BuildContext context) {
    final series = fin.monthlySeries(from: months.first, to: months.last);
    final inc = series.fold(0, (s, m) => s + m.income);
    final exp = series.fold(0, (s, m) => s + m.expense);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('সারাংশ · $label', 'Summary · $label'), style: _h1),
        const SizedBox(height: 10),
        _kv(tr('মোট জমা', 'Total income'), money(inc), color: AppColors.income),
        _kv(tr('মোট খরচ', 'Total expense'), money(exp), color: AppColors.expense),
        _kv(tr('সঞ্চয়', 'Savings'), money(inc - exp), bold: true),
        _kv(tr('বর্তমান ব্যালেন্স', 'Current balance'), money(fin.currentBalance)),
        const SizedBox(height: 14),
        Text(tr('মাসিক ট্রেন্ড', 'Monthly trend'), style: _h2),
        const SizedBox(height: 6),
        TrendChart(series: series, height: 200),
        const SizedBox(height: 14),
        Table(
          border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)),
          children: [
            TableRow(
              children: [
                Text(
                  tr('মাস', 'Month'),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
                Text(
                  tr('জমা', 'Income'),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
                Text(
                  tr('খরচ', 'Expense'),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
                Text(
                  tr('সঞ্চয়', 'Savings'),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            for (final m in series.length > 18 ? series.sublist(series.length - 18) : series)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(monthLabel(m.month), style: const TextStyle(fontSize: 10)),
                  ),
                  Text(
                    money(m.income),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    money(m.expense),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    money(m.saving),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _DebtPage extends StatelessWidget {
  const _DebtPage({required this.debts});
  final List<PersonDebt> debts;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        tr('বাকি ধার (আজ পর্যন্ত)', 'Outstanding debts (as of today)'),
        style: _h1.copyWith(color: AppColors.debt),
      ),
      const SizedBox(height: 10),
      _kv(
        tr('মোট আমি দেব', 'Total I owe'),
        money(debts.fold(0, (s, d) => s + (d.payable > 0 ? d.payable : 0))),
        color: AppColors.expense,
      ),
      _kv(
        tr('মোট আমি পাব', 'Total owed to me'),
        money(debts.fold(0, (s, d) => s + (d.receivable > 0 ? d.receivable : 0))),
        color: AppColors.income,
      ),
      const SizedBox(height: 10),
      HBarList(
        items: [
          for (final d in debts) ...[
            if (d.payable > 0) HBarItem(d.person.id, d.person.name, d.payable, AppColors.expense),
            if (d.receivable > 0)
              HBarItem(d.person.id, d.person.name, d.receivable, AppColors.income),
          ],
        ],
      ),
    ],
  );
}
