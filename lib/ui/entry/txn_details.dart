import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/i18n.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../debt/person_screen.dart';
import '../widgets/common.dart';
import 'entry_sheet.dart';

/// একটি লেনদেনের পূর্ণ বিবরণ — নিচে এডিট ও ডিলিট
Future<void> showTxnDetails(BuildContext context, Txn txn) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (context, controller) =>
          TxnDetails(id: txn.id, initial: txn, controller: controller),
    ),
  );
}

/// জিজ্ঞেস করে ডিলিট, তারপর ৫ সেকেন্ডের Undo। ডিলিট হলে true।
Future<bool> deleteTxnWithUndo(BuildContext context, WidgetRef ref, Txn t) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await confirm(
    context,
    tr('এন্ট্রি মুছবেন?', 'Delete this entry?'),
    body: tr(
      '${money(t.amount)} · ${dateTimeLabel(t.occurredAt)}',
      '${money(t.amount)} · ${dateTimeLabel(t.occurredAt)}',
    ),
    ok: tr('মুছুন', 'Delete'),
    danger: true,
  );
  if (!ok) return false;
  final repo = ref.read(repoProvider);
  final effects = ref.read(effectsProvider);
  await repo.deleteTxn(t.id);
  HapticFeedback.mediumImpact();
  effects.afterDelete(t.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          tr('এন্ট্রি মুছে ফেলা হয়েছে (${money(t.amount)})', 'Entry deleted (${money(t.amount)})'),
        ),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: tr('ফিরিয়ে আনুন', 'Undo'),
          onPressed: () async {
            await repo.insertTxn(t);
            effects.afterSave(t);
          },
        ),
      ),
    );
  return true;
}

class TxnDetails extends ConsumerWidget {
  const TxnDetails({super.key, required this.id, required this.initial, required this.controller});
  final String id;
  final Txn initial;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(financeProvider);
    // এডিটের পরে নতুন তথ্য দেখাতে সবসময় সর্বশেষ সংস্করণ
    final t = fin.txns.where((x) => x.id == id).firstOrNull ?? initial;
    final cat = fin.catById[t.categoryId];
    final person = t.personId == null ? null : fin.personById[t.personId];
    final wallet = t.walletId == null ? null : fin.walletById[t.walletId];
    final isDebt = t.debtAction != null;
    final color = isDebt ? AppColors.debt : AppColors.forType(t.type);
    final scheme = Theme.of(context).colorScheme;
    final tags = tagsOf(t);

    Widget row(IconData icon, String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.outline),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Text(label, style: TextStyle(color: scheme.outline)),
          ),
          Expanded(child: value),
        ],
      ),
    );
    Text val(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.w600));

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Row(
                children: [
                  CatAvatar.of(cat, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat?.name ?? tr('অজানা', 'Unknown'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            _Pill(TxType.label(t.type), AppColors.forType(t.type)),
                            if (isDebt) _Pill(DebtAction.fullLabel(t.debtAction!), AppColors.debt),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: FittedBox(
                  child: Text(
                    money(t.type == TxType.expense ? -t.amount : t.amount, signed: true),
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: color),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              row(
                Icons.event,
                tr('তারিখ', 'Date'),
                val(
                  '${weekdayName(t.occurredAt.weekday)}, ${dayLabel(t.occurredAt, withYear: true)}',
                ),
              ),
              row(Icons.schedule, tr('সময়', 'Time'), val(timeLabel(t.occurredAt))),
              if (person != null)
                row(
                  Icons.person_outline,
                  tr('ব্যক্তি', 'Person'),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PersonScreen(personId: person.id)),
                      );
                    },
                    child: Text(
                      person.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              if (t.dueDate != null)
                row(
                  Icons.alarm,
                  t.debtAction == DebtAction.borrow
                      ? tr('শোধের তারিখ', 'Repay by')
                      : tr('ফেরতের তারিখ', 'Return by'),
                  val(dayLabel(t.dueDate!, withYear: true)),
                ),
              if (wallet != null)
                row(
                  Icons.account_balance_wallet_outlined,
                  tr('ওয়ালেট', 'Wallet'),
                  val('${wallet.emoji} ${wallet.name}'),
                ),
              row(Icons.notes, tr('বিবরণ', 'Note'), val(t.note.isEmpty ? '—' : t.note)),
              row(
                Icons.flag_outlined,
                tr('উদ্দেশ্য', 'Purpose'),
                val(t.purpose.isEmpty ? '—' : t.purpose),
              ),
              if (tags.isNotEmpty)
                row(
                  Icons.tag,
                  tr('ট্যাগ', 'Tags'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final g in tags)
                        Chip(label: Text(g), visualDensity: VisualDensity.compact),
                    ],
                  ),
                ),
              if (t.photoPath != null) ...[
                row(Icons.receipt_long, tr('রসিদ', 'Receipt'), const SizedBox()),
                GestureDetector(
                  onTap: () => showPhoto(context, t.photoPath!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(t.photoPath!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 80,
                        alignment: Alignment.center,
                        color: scheme.surfaceContainerHighest,
                        child: Text(tr('ছবিটি পাওয়া যায়নি', 'Photo not found')),
                      ),
                    ),
                  ),
                ),
              ],
              const Divider(height: 28),
              Text(
                [
                  tr(
                    'যোগ করা হয়েছে: ${dateTimeLabel(t.createdAt)}',
                    'Added: ${dateTimeLabel(t.createdAt)}',
                  ),
                  if (t.updatedAt.difference(t.createdAt).inSeconds.abs() > 2)
                    tr(
                      'শেষ বদল: ${dateTimeLabel(t.updatedAt)}',
                      'Last edited: ${dateTimeLabel(t.updatedAt)}',
                    ),
                ].join('\n'),
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
              const SizedBox(height: 4),
              SelectableText('ID: ${t.id}', style: TextStyle(fontSize: 11, color: scheme.outline)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.expense,
                      side: const BorderSide(color: AppColors.expense),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      if (await deleteTxnWithUndo(context, ref, t)) nav.pop();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(tr('ডিলিট', 'Delete')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () {
                      // বিবরণ বন্ধ করে এডিট শিট খোলা
                      final rootContext = Navigator.of(context).context;
                      Navigator.pop(context);
                      showEntrySheet(rootContext, edit: t);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(tr('এডিট', 'Edit')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}
