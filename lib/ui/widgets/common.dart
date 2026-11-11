import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import 'logo.dart';

/// ‹ নভেম্বর ২০২৬ ›
class MonthSwitcher extends ConsumerWidget {
  const MonthSwitcher({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(selectedMonthProvider);
    final isCurrent = sameMonth(m, DateTime.now());
    final n = ref.read(selectedMonthProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => n.set(prevMonth(m)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickMonth(context, ref, m),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              monthLabel(m),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right),
          onPressed: isCurrent ? null : () => n.set(nextMonth(m)),
        ),
        if (!isCurrent && !compact)
          TextButton(
            onPressed: () => n.set(monthStart(DateTime.now())),
            child: const Text('এ মাস'),
          ),
      ],
    );
  }

  Future<void> _pickMonth(BuildContext context, WidgetRef ref, DateTime m) async {
    final picked = await showMonthPicker(context, m);
    if (picked != null) ref.read(selectedMonthProvider.notifier).set(picked);
  }
}

/// মাস বাছাইয়ের ডায়ালগ
Future<DateTime?> showMonthPicker(BuildContext context, DateTime initial) {
  var year = initial.year;
  final now = DateTime.now();
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => year--),
            ),
            Expanded(child: Center(child: Text(dg(year)))),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: year >= now.year ? null : () => setState(() => year++),
            ),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 2,
            children: [
              for (var i = 1; i <= 12; i++)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: Text(bnMonths[i - 1], style: const TextStyle(fontSize: 12)),
                    selected: initial.year == year && initial.month == i,
                    onSelected: DateTime(year, i).isAfter(now)
                        ? null
                        : (_) => Navigator.pop(ctx, DateTime(year, i)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CatAvatar extends StatelessWidget {
  const CatAvatar({super.key, required this.emoji, required this.color, this.size = 40});
  CatAvatar.of(Cat? c, {super.key, this.size = 40})
    : emoji = c?.emoji ?? '❓',
      color = c == null ? Colors.grey : Color(c.color);
  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Text(emoji, style: TextStyle(fontSize: size * .5)),
  );
}

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.paisa, {
    super.key,
    this.type,
    this.style,
    this.signed = false,
    this.color,
  });
  final int paisa;
  final int? type;
  final TextStyle? style;
  final bool signed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (type == null ? null : AppColors.forType(type!));
    final v = type == TxType.expense && signed ? -paisa : paisa;
    return Text(
      money(v, signed: signed),
      style: (style ?? const TextStyle()).copyWith(
        color: c,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              // কার্ডের ভেতরে প্যাডিং না থাকলে (তালিকার কার্ড) শিরোনামে আলাদা ফাঁক
              padding: EdgeInsets.only(
                bottom: 12,
                left: padding.left == 0 ? 16 : 0,
                right: padding.right == 0 ? 8 : 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.emoji,
  });
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? emoji;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 64))
          else
            const AppLogo(size: 88),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

/// একটি এন্ট্রির সারি
class TxnTile extends StatelessWidget {
  const TxnTile({
    super.key,
    required this.txn,
    required this.fin,
    this.onTap,
    this.showDate = false,
    this.trailingExtra,
  });
  final Txn txn;
  final FinanceData fin;
  final VoidCallback? onTap;
  final bool showDate;
  final Widget? trailingExtra;

  @override
  Widget build(BuildContext context) {
    final cat = fin.catById[txn.categoryId];
    final person = txn.personId == null ? null : fin.personById[txn.personId];
    final wallet = txn.walletId == null ? null : fin.walletById[txn.walletId];
    var title = cat?.name ?? 'অজানা';
    if (txn.debtAction != null) {
      title = '${DebtAction.fullLabel(txn.debtAction!)}${person != null ? ' · ${person.name}' : ''}';
    }
    final parts = <String>[
      if (showDate) dayLabel(txn.occurredAt),
      timeLabel(txn.occurredAt),
      if (txn.note.isNotEmpty) txn.note,
      if (txn.purpose.isNotEmpty) txn.purpose,
      if (wallet != null && fin.wallets.length > 1) '${wallet.emoji} ${wallet.name}',
    ];
    final outline = Theme.of(context).colorScheme.outline;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CatAvatar.of(cat),
      title: Row(
        children: [
          Flexible(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (txn.photoPath != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.receipt_long, size: 14, color: outline),
          ],
        ],
      ),
      subtitle: Text(
        parts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: outline, fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(
            txn.amount,
            type: txn.type,
            signed: true,
            color: txn.debtAction != null ? AppColors.debt : null,
          ),
          ?trailingExtra,
        ],
      ),
    );
  }
}

/// রসিদের ছবি দেখানো
void showPhoto(BuildContext context, String path) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        child: File(path).existsSync()
            ? Image.file(File(path))
            : const Padding(
                padding: EdgeInsets.all(32),
                child: Text('ছবিটি পাওয়া যায়নি'),
              ),
      ),
    ),
  );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirm(
  BuildContext context,
  String title, {
  String? body,
  String ok = 'হ্যাঁ',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('বাতিল'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppColors.expense)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// ছোট লেবেল-মান জোড়া
class StatLine extends StatelessWidget {
  const StatLine(this.label, this.value, {super.key, this.color, this.bold = false});
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class ColorDot extends StatelessWidget {
  const ColorDot(this.color, {super.key, this.size = 10});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
