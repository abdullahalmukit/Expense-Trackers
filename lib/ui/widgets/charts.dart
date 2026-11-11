import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../domain/finance.dart';
import '../../core/i18n.dart';

/// চার্টে অ্যানিমেশন — রিপোর্ট রেন্ডারে বন্ধ রাখা হয়।
class ChartAnim {
  static Duration duration = const Duration(milliseconds: 350);
}

class Slice {
  final int id;
  final String label;
  final String emoji;
  final int value;
  final Color color;
  const Slice(this.id, this.label, this.emoji, this.value, this.color);
}

/// ক্যাটাগরিভিত্তিক ভাগ (%) — ডোনাট, পাশে লেজেন্ড
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.onTap,
    this.centerTitle,
    this.size = 170,
    this.maxLegend = 6,
  });
  final List<Slice> slices;
  final ValueChanged<int>? onTap;
  final String? centerTitle;
  final double size;
  final int maxLegend;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.slices.fold(0, (s, e) => s + e.value);
    if (total == 0) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            tr('এই সময়ে কোনো এন্ট্রি নেই', 'No entries in this period'),
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }
    final slices = [...widget.slices]..sort((a, b) => b.value.compareTo(a.value));
    return Row(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: widget.size * .3,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, resp) {
                      final i = resp?.touchedSection?.touchedSectionIndex ?? -1;
                      if (event is FlTapUpEvent && i >= 0 && i < slices.length) {
                        widget.onTap?.call(slices[i].id);
                      }
                      if (event.isInterestedForInteractions) {
                        if (_touched != i) setState(() => _touched = i);
                      } else if (_touched != -1) {
                        setState(() => _touched = -1);
                      }
                    },
                  ),
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].value.toDouble(),
                        color: slices[i].color,
                        radius: widget.size * (i == _touched ? .2 : .17),
                        showTitle: false,
                      ),
                  ],
                ),
                duration: ChartAnim.duration,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.centerTitle != null)
                    Text(widget.centerTitle!, style: const TextStyle(fontSize: 11)),
                  Text(
                    _touched >= 0 && _touched < slices.length
                        ? percent(slices[_touched].value / total * 100)
                        : moneyCompact(total),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices.take(widget.maxLegend))
                InkWell(
                  onTap: widget.onTap == null ? null : () => widget.onTap!(s.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${s.emoji} ${s.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          percent(s.value / total * 100),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              if (slices.length > widget.maxLegend)
                Text(
                  tr(
                    '+ আরও ${dg(slices.length - widget.maxLegend)}টি',
                    '+ ${dg(slices.length - widget.maxLegend)} more',
                  ),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

FlTitlesData _titles({
  required Widget Function(double v, TitleMeta meta) bottom,
  double reserved = 40,
  bool showLeft = true,
  double bottomReserved = 24,
}) => FlTitlesData(
  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: showLeft,
      reservedSize: reserved,
      getTitlesWidget: (v, meta) {
        if (v == meta.max || v == meta.min && v == 0) return const SizedBox.shrink();
        return SideTitleWidget(
          meta: meta,
          child: Text(moneyCompact((v * 100).round()), style: const TextStyle(fontSize: 10)),
        );
      },
    ),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: bottomReserved,
      interval: 1,
      getTitlesWidget: bottom,
    ),
  ),
);

FlGridData _grid(BuildContext context) => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) => FlLine(
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .5),
    strokeWidth: 1,
  ),
);

Color _tooltipBg(BuildContext context) => Theme.of(context).colorScheme.inverseSurface;
TextStyle _tooltipText(BuildContext context) => TextStyle(
  color: Theme.of(context).colorScheme.onInverseSurface,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

/// দৈনিক বার — গড়ের রেখা সহ
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({
    super.key,
    required this.values,
    required this.start,
    this.color = AppColors.expense,
    this.onTapDay,
    this.height = 200,
  });
  final List<int> values;
  final DateTime start;
  final Color color;
  final ValueChanged<int>? onTapDay;
  final double height;

  @override
  Widget build(BuildContext context) {
    final n = values.length;
    final nonZeroDays = math.max(1, n);
    final avg = values.fold(0, (s, v) => s + v) / nonZeroDays / 100;
    final maxV = values.fold(0, math.max) / 100;
    final step = n <= 10 ? 1 : (n <= 31 ? 5 : (n / 6).ceil());
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxV == 0 ? 100 : maxV * 1.15,
          gridData: _grid(context),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (avg > 0)
                HorizontalLine(
                  y: avg,
                  color: AppColors.brand.withValues(alpha: .7),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    labelResolver: (_) => tr(
                      'গড় ${moneyCompact((avg * 100).round())}',
                      'avg ${moneyCompact((avg * 100).round())}',
                    ),
                  ),
                ),
            ],
          ),
          titlesData: _titles(
            bottom: (v, meta) {
              final i = v.toInt();
              if (i % step != 0 && i != n - 1) return const SizedBox.shrink();
              final d = start.add(Duration(days: i));
              return SideTitleWidget(
                meta: meta,
                child: Text(dg(d.day), style: const TextStyle(fontSize: 10)),
              );
            },
          ),
          barTouchData: BarTouchData(
            touchCallback: (event, resp) {
              final i = resp?.spot?.touchedBarGroupIndex;
              if (event is FlTapUpEvent && i != null) onTapDay?.call(i);
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _tooltipBg(context),
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${dayLabel(start.add(Duration(days: group.x)))}\n${money((rod.toY * 100).round())}',
                _tooltipText(context),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < n; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i] / 100,
                    color: color,
                    width: n > 40 ? 3 : (n > 20 ? 6 : 12),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
              ),
          ],
        ),
        duration: ChartAnim.duration,
      ),
    );
  }
}

/// মাসে এ পর্যন্ত খরচ বনাম বাজেট ও গত মাস
class CumulativeChart extends StatelessWidget {
  const CumulativeChart({
    super.key,
    required this.current,
    required this.lastMonth,
    required this.month,
    this.budget,
    this.height = 190,
  });
  final List<int> current;
  final List<int> lastMonth;
  final DateTime month;
  final int? budget;
  final double height;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = daysInMonth(month);
    final upTo = sameMonth(month, now) ? now.day : days;
    final cur = [
      for (var i = 0; i < upTo && i < current.length; i++) FlSpot(i + 1.0, current[i] / 100),
    ];
    final last = [
      for (var i = 0; i < lastMonth.length && i < days; i++) FlSpot(i + 1.0, lastMonth[i] / 100),
    ];
    final maxY = [
      ...cur.map((s) => s.y),
      ...last.map((s) => s.y),
      (budget ?? 0) / 100,
    ].fold(0.0, math.max);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 1,
              maxX: days.toDouble(),
              minY: 0,
              maxY: maxY == 0 ? 100 : maxY * 1.1,
              gridData: _grid(context),
              borderData: FlBorderData(show: false),
              titlesData: _titles(
                bottom: (v, meta) {
                  final d = v.toInt();
                  if (d != 1 && d % 5 != 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(dg(d), style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (budget != null)
                    HorizontalLine(
                      y: budget! / 100,
                      color: AppColors.expense.withValues(alpha: .8),
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topLeft,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.expense,
                        ),
                        labelResolver: (_) => tr('বাজেট', 'Budget'),
                      ),
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => _tooltipBg(context),
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        tr(
                          '${s.barIndex == 0 ? 'এ মাস' : 'গত মাস'} ${dg(s.x.toInt())}: ${money((s.y * 100).round())}',
                          '${s.barIndex == 0 ? 'This month' : 'Last month'} ${dg(s.x.toInt())}: ${money((s.y * 100).round())}',
                        ),
                        _tooltipText(context),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: cur.isEmpty ? [const FlSpot(1, 0)] : cur,
                  color: AppColors.expense,
                  barWidth: 3,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.expense.withValues(alpha: .12),
                  ),
                ),
                if (last.isNotEmpty)
                  LineChartBarData(
                    spots: last,
                    color: Theme.of(context).colorScheme.outline,
                    barWidth: 2,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    dashArray: [5, 4],
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
            duration: ChartAnim.duration,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          children: [
            _Legend(AppColors.expense, tr('এ মাস', 'This month')),
            _Legend(
              Theme.of(context).colorScheme.outline,
              tr('গত মাসের একই দিন', 'Same day last month'),
            ),
            if (budget != null)
              _Legend(
                AppColors.expense.withValues(alpha: .6),
                tr('বাজেট ${money(budget!)}', 'Budget ${money(budget!)}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 3, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

/// মাস বনাম মাস জমা, খরচ, সঞ্চয়
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.series, this.onTapMonth, this.height = 220});
  final List<MonthTotals> series;
  final ValueChanged<DateTime>? onTapMonth;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return SizedBox(height: 60, child: Center(child: Text(tr('ডাটা নেই', 'No data'))));
    }
    final n = series.length;
    final step = (n / 6).ceil();
    List<FlSpot> spots(int Function(MonthTotals) f) => [
      for (var i = 0; i < n; i++) FlSpot(i.toDouble(), f(series[i]) / 100),
    ];
    final values = [
      for (final m in series) ...[m.income, m.expense, m.saving],
    ];
    final maxY = values.fold(0, math.max) / 100;
    final minY = math.min(0, values.fold(0, math.min)) / 100;
    LineChartBarData line(List<FlSpot> s, Color c, {bool dashed = false}) => LineChartBarData(
      spots: s,
      color: c,
      barWidth: dashed ? 2 : 3,
      isCurved: true,
      preventCurveOverShooting: true,
      dashArray: dashed ? [5, 4] : null,
      dotData: FlDotData(show: n <= 12),
    );
    return Column(
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(1, n - 1).toDouble(),
              minY: minY * 1.1,
              maxY: maxY == 0 ? 100 : maxY * 1.1,
              gridData: _grid(context),
              borderData: FlBorderData(show: false),
              titlesData: _titles(
                bottom: (v, meta) {
                  final i = v.toInt();
                  if (v != i.toDouble() || i < 0 || i >= n || (i % step != 0 && i != n - 1)) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      monthShortLabel(series[i].month),
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
              lineTouchData: LineTouchData(
                touchCallback: (event, resp) {
                  final s = resp?.lineBarSpots;
                  if (event is FlTapUpEvent && s != null && s.isNotEmpty) {
                    onTapMonth?.call(series[s.first.x.toInt()].month);
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => _tooltipBg(context),
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        tr(
                          '${['জমা', 'খরচ', 'সঞ্চয়'][s.barIndex]}: ${money((s.y * 100).round())}',
                          '${['Income', 'Expense', 'Savings'][s.barIndex]}: ${money((s.y * 100).round())}',
                        ),
                        _tooltipText(context),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                line(spots((m) => m.income), AppColors.income),
                line(spots((m) => m.expense), AppColors.expense),
                line(spots((m) => m.saving), AppColors.brand, dashed: true),
              ],
            ),
            duration: ChartAnim.duration,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          children: [
            _Legend(AppColors.income, tr('জমা', 'Income')),
            _Legend(AppColors.expense, tr('খরচ', 'Expense')),
            _Legend(AppColors.brand, tr('সঞ্চয়', 'Savings')),
          ],
        ),
      ],
    );
  }
}

/// প্রতি মাসে ক্যাটাগরির ভাগ — স্ট্যাকড বার
class StackedMonthChart extends StatelessWidget {
  const StackedMonthChart({
    super.key,
    required this.months,
    required this.data,
    required this.colors,
    this.onTapMonth,
    this.height = 220,
  });
  final List<DateTime> months;

  /// প্রতিটি মাসের জন্য categoryId → টাকা
  final List<Map<int, int>> data;
  final Map<int, Color> colors;
  final ValueChanged<DateTime>? onTapMonth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final n = months.length;
    if (n == 0) {
      return SizedBox(height: 60, child: Center(child: Text(tr('ডাটা নেই', 'No data'))));
    }
    final totals = [for (final m in data) m.values.fold(0, (s, v) => s + v)];
    final maxY = totals.fold(0, math.max) / 100;
    final step = (n / 6).ceil();
    // ক্রম স্থির রাখতে সব মাসের মোট অনুযায়ী ক্যাটাগরি সাজানো
    final order = <int, int>{};
    for (final m in data) {
      m.forEach((k, v) => order[k] = (order[k] ?? 0) + v);
    }
    final ids = order.keys.toList()..sort((a, b) => order[b]!.compareTo(order[a]!));
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 100 : maxY * 1.1,
          gridData: _grid(context),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            bottom: (v, meta) {
              final i = v.toInt();
              if (i % step != 0 && i != n - 1) return SizedBox.shrink();
              return SideTitleWidget(
                meta: meta,
                child: Text(monthShortLabel(months[i]), style: TextStyle(fontSize: 9)),
              );
            },
          ),
          barTouchData: BarTouchData(
            touchCallback: (event, resp) {
              final i = resp?.spot?.touchedBarGroupIndex;
              if (event is FlTapUpEvent && i != null) onTapMonth?.call(months[i]);
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _tooltipBg(context),
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${monthLabel(months[group.x])}\n${money((rod.toY * 100).round())}',
                _tooltipText(context),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < n; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: totals[i] / 100,
                    width: n > 24 ? 6 : 14,
                    borderRadius: BorderRadius.zero,
                    rodStackItems: () {
                      var y = 0.0;
                      final items = <BarChartRodStackItem>[];
                      for (final id in ids) {
                        final v = (data[i][id] ?? 0) / 100;
                        if (v <= 0) continue;
                        items.add(BarChartRodStackItem(y, y + v, colors[id] ?? Colors.grey));
                        y += v;
                      }
                      return items;
                    }(),
                  ),
                ],
              ),
          ],
        ),
        duration: ChartAnim.duration,
      ),
    );
  }
}

class ScatterPoint {
  final String id;
  final double hour; // 0–24
  final int amount;
  final Color color;
  const ScatterPoint(this.id, this.hour, this.amount, this.color);
}

/// দিনের সময় বনাম টাকা — কখন বড় খরচ হয়
class TimeScatterChart extends StatelessWidget {
  const TimeScatterChart({super.key, required this.points, this.onTap, this.height = 220});
  final List<ScatterPoint> points;
  final ValueChanged<String>? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: 60, child: Center(child: Text(tr('ডাটা নেই', 'No data'))));
    }
    final maxY = points.map((p) => p.amount).fold(0, math.max) / 100;
    return SizedBox(
      height: height,
      child: ScatterChart(
        ScatterChartData(
          minX: 0,
          maxX: 24,
          minY: 0,
          maxY: maxY == 0 ? 100 : maxY * 1.1,
          gridData: _grid(context),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, meta) => v == meta.max
                    ? SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(
                          moneyCompact((v * 100).round()),
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 6,
                reservedSize: 24,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    {
                          0: tr('রাত ১২', '12 AM'),
                          6: tr('সকাল ৬', '6 AM'),
                          12: tr('দুপুর ১২', '12 PM'),
                          18: tr('সন্ধ্যা ৬', '6 PM'),
                          24: tr('রাত ১২', '12 AM'),
                        }[v.toInt()] ??
                        '',
                    style: TextStyle(fontSize: 9),
                  ),
                ),
              ),
            ),
          ),
          scatterTouchData: ScatterTouchData(
            touchCallback: (event, resp) {
              final i = resp?.touchedSpot?.spotIndex;
              if (event is FlTapUpEvent && i != null && i < points.length) {
                onTap?.call(points[i].id);
              }
            },
            touchTooltipData: ScatterTouchTooltipData(
              getTooltipColor: (_) => _tooltipBg(context),
              getTooltipItems: (s) =>
                  ScatterTooltipItem(money((s.y * 100).round()), textStyle: _tooltipText(context)),
            ),
          ),
          scatterSpots: [
            for (final p in points)
              ScatterSpot(
                p.hour,
                p.amount / 100,
                dotPainter: FlDotCirclePainter(
                  radius: 5,
                  color: p.color.withValues(alpha: .75),
                  strokeWidth: 0,
                ),
              ),
          ],
        ),
        duration: ChartAnim.duration,
      ),
    );
  }
}

/// ক্যালেন্ডার হিটম্যাপ — কোন দিন কত খরচ, রঙের গাঢ়তায়
class CalendarHeatmap extends StatelessWidget {
  const CalendarHeatmap({
    super.key,
    required this.month,
    required this.values,
    this.onTapDay,
    this.selectedDay,
  });
  final DateTime month;
  final List<int> values;
  final ValueChanged<DateTime>? onTapDay;
  final int? selectedDay;

  @override
  Widget build(BuildContext context) {
    final days = daysInMonth(month);
    // শনিবার থেকে সপ্তাহ শুরু (বাংলাদেশে প্রচলিত)
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1=Mon
    final offset = (firstWeekday + 1) % 7; // শনি=0
    final maxV = values.fold(0, math.max);
    final scheme = Theme.of(context).colorScheme;
    final headers = [
      tr('শনি', 'Sat'),
      tr('রবি', 'Sun'),
      tr('সোম', 'Mon'),
      tr('মঙ্গল', 'Tue'),
      tr('বুধ', 'Wed'),
      tr('বৃহঃ', 'Thu'),
      tr('শুক্র', 'Fri'),
    ];
    final cells = <Widget>[
      for (final h in headers)
        Center(
          child: Text(h, style: TextStyle(fontSize: 10, color: scheme.outline)),
        ),
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++)
        Builder(
          builder: (context) {
            final v = d - 1 < values.length ? values[d - 1] : 0;
            final t = maxV == 0 ? 0.0 : v / maxV;
            final isToday = sameDay(DateTime(month.year, month.month, d), DateTime.now());
            return GestureDetector(
              onTap: onTapDay == null
                  ? null
                  : () => onTapDay!(DateTime(month.year, month.month, d)),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: v == 0
                      ? scheme.surfaceContainerHighest.withValues(alpha: .5)
                      : Color.lerp(AppColors.expense.withValues(alpha: .15), AppColors.expense, t),
                  borderRadius: BorderRadius.circular(8),
                  border: selectedDay == d
                      ? Border.all(color: scheme.primary, width: 2)
                      : (isToday ? Border.all(color: scheme.outline) : null),
                ),
                child: Center(
                  child: Text(
                    dg(d),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t > .55 ? Colors.white : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: cells,
    );
  }
}

/// কার কাছে কত বাকি — অনুভূমিক বার
class HBarList extends StatelessWidget {
  const HBarList({super.key, required this.items, this.onTap});
  final List<HBarItem> items;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final maxV = items.fold(0, (m, e) => math.max(m, e.value.abs()));
    return Column(
      children: [
        for (final it in items)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(it.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: ChartAnim.duration,
                          height: 16,
                          width: maxV == 0 ? 0 : math.max(4, c.maxWidth * it.value.abs() / maxV),
                          decoration: BoxDecoration(
                            color: it.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    money(it.value.abs()),
                    style: TextStyle(fontWeight: FontWeight.w700, color: it.color),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class HBarItem {
  final int id;
  final String label;
  final int value;
  final Color color;
  const HBarItem(this.id, this.label, this.value, this.color);
}
