import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repo.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

/// মেস ভাড়া, ইন্টারনেট বিল — প্রতি মাসে নিজে থেকে যোগ হবে বা মনে করিয়ে দেবে
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(recurringsProvider).value ?? const <Recurring>[];
    final fin = ref.watch(financeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('রিকারিং এন্ট্রি', 'Recurring entries'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecurringEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text(tr('নতুন', 'New')),
      ),
      body: list.isEmpty
          ? EmptyState(
              emoji: '🔁',
              title: tr('কোনো রিকারিং এন্ট্রি নেই', 'No recurring entries'),
              subtitle: tr(
                'মেস ভাড়া, ইন্টারনেট বিল ইত্যাদি প্রতি মাসে নিজে থেকে যোগ হবে',
                'Rent, internet bills and so on get added every month automatically',
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                for (final r in list)
                  ListTile(
                    leading: CatAvatar.of(fin.catById[r.categoryId]),
                    title: Text(r.title),
                    subtitle: Text(
                      tr(
                        'প্রতি মাসের ${dg(r.dayOfMonth)} তারিখ · ${r.autoAdd ? 'নিজে যোগ হবে' : 'মনে করাবে'}\nপরেরটা ${dayLabel(r.nextDate, withYear: true)}',
                        'Day ${dg(r.dayOfMonth)} of every month · ${r.autoAdd ? 'added automatically' : 'reminder only'}\nNext: ${dayLabel(r.nextDate, withYear: true)}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(r.amount, type: r.type),
                        if (!r.active) Text(tr('বন্ধ', 'Off'), style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    onTap: () => showRecurringEditor(context, ref, r),
                  ),
              ],
            ),
    );
  }
}

Future<void> showRecurringEditor(BuildContext context, WidgetRef ref, Recurring? r) async {
  final fin = ref.read(financeProvider);
  final title = TextEditingController(text: r?.title ?? '');
  final amount = TextEditingController(text: r == null ? '' : paisaToPlain(r.amount));
  var type = r?.type ?? TxType.expense;
  int? cat = r?.categoryId;
  var day = r?.dayOfMonth ?? DateTime.now().day;
  var auto = r?.autoAdd ?? true;
  var active = r?.active ?? true;
  final res = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final cats = fin.cats.where((c) => c.kind == type && !c.archived && !c.isDebt).toList();
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  r == null
                      ? tr('নতুন রিকারিং', 'New recurring entry')
                      : tr('রিকারিং এডিট', 'Edit recurring entry'),
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(tr('খরচ', 'Expense'))),
                    ButtonSegment(value: 1, label: Text(tr('জমা', 'Income'))),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setState(() {
                    type = s.first;
                    cat = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: tr('নাম (যেমন মেস ভাড়া)', 'Name (e.g. Rent)'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: tr('টাকা ৳', 'Amount ৳')),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    for (final c in cats)
                      ChoiceChip(
                        label: Text('${c.emoji} ${c.name}'),
                        selected: cat == c.id,
                        onSelected: (_) => setState(() => cat = c.id),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(tr('প্রতি মাসের', 'Every month on')),
                    const SizedBox(width: 10),
                    DropdownButton<int>(
                      value: day,
                      items: [
                        for (var i = 1; i <= 31; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(tr('${dg(i)} তারিখ', 'day ${dg(i)}')),
                          ),
                      ],
                      onChanged: (v) => setState(() => day = v!),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('নিজে থেকে এন্ট্রি যোগ হবে', 'Add the entry automatically')),
                  subtitle: Text(
                    tr(
                      'বন্ধ থাকলে শুধু নোটিফিকেশনে মনে করাবে',
                      'If off, you only get a reminder notification',
                    ),
                  ),
                  value: auto,
                  onChanged: (v) => setState(() => auto = v),
                ),
                if (r != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('চালু', 'Active')),
                    value: active,
                    onChanged: (v) => setState(() => active = v),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (r != null)
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'delete'),
                        child: Text(tr('মুছুন', 'Delete')),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'save'),
                      child: Text(tr('সেভ', 'Save')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  final repo = ref.read(repoProvider);
  if (res == 'delete' && r != null) {
    await repo.deleteRecurring(r.id);
    return;
  }
  if (res != 'save') return;
  final a = parseMoney(amount.text);
  if (a == null || a <= 0 || cat == null || title.text.trim().isEmpty) {
    if (context.mounted) {
      toast(context, tr('নাম, টাকা আর ক্যাটাগরি দিন', 'Enter a name, amount and category'));
    }
    return;
  }
  final dayChanged = r == null || r.dayOfMonth != day;
  await repo.saveRecurring(
    RecurringsCompanion(
      id: r == null ? const Value.absent() : Value(r.id),
      title: Value(title.text.trim()),
      type: Value(type),
      amount: Value(a),
      categoryId: Value(cat!),
      dayOfMonth: Value(day),
      autoAdd: Value(auto),
      active: Value(active),
      nextDate: Value(dayChanged ? firstOccurrence(day) : r.nextDate),
    ),
  );
  await repo.processRecurring();
}
