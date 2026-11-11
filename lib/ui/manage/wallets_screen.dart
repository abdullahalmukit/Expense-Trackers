import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import '../widgets/emoji_pick.dart';
import '../../core/i18n.dart';

/// ক্যাশ, bKash, Nagad, ব্যাংক — আলাদা ব্যালেন্স আর ট্রান্সফার
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(financeProvider);
    final bal = fin.walletBalances();
    final transfers = ref.watch(transfersProvider).value ?? const <Transfer>[];
    final total = bal.values.fold(0, (s, v) => s + v);
    return Scaffold(
      appBar: AppBar(title: Text(tr('ওয়ালেট', 'Wallets'))),
      floatingActionButton: fin.wallets.where((w) => !w.archived).length >= 2
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _transfer(context, ref, fin.wallets.where((w) => !w.archived).toList()),
              icon: const Icon(Icons.swap_horiz),
              label: Text(tr('ট্রান্সফার', 'Transfer')),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Card(
            child: ListTile(
              title: Text(tr('সব ওয়ালেটে মোট', 'Total across wallets')),
              trailing: Text(
                money(total),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final w in fin.wallets)
                  ListTile(
                    leading: Text(w.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(w.name + (w.archived ? tr(' (লুকানো)', ' (hidden)') : '')),
                    subtitle: Text(
                      tr(
                        'শুরুর ব্যালেন্স ${money(w.openingBalance)}',
                        'Opening balance ${money(w.openingBalance)}',
                      ),
                    ),
                    trailing: Text(
                      money(bal[w.id] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () => _edit(context, ref, w),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(tr('নতুন ওয়ালেট', 'New wallet')),
                  onTap: () => _edit(context, ref, null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              tr(
                'ট্রান্সফার খরচ বা জমা হিসেবে গোনা হয় না। প্রথম ওয়ালেটের শুরুর ব্যালেন্সই অ্যাপ শুরুর সময় আপনার হাতে থাকা টাকা।',
                'Transfers are not counted as income or expense. A wallet\'s opening balance is the money you had when you started using the app.',
              ),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
          ),
          if (transfers.isNotEmpty)
            SectionCard(
              title: tr('ট্রান্সফার', 'Transfer'),
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Column(
                children: [
                  for (final t in transfers)
                    ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: Text(
                        '${fin.walletById[t.fromWalletId]?.name ?? '?'} → ${fin.walletById[t.toWalletId]?.name ?? '?'}',
                      ),
                      subtitle: Text(
                        [dateTimeLabel(t.occurredAt), if (t.note.isNotEmpty) t.note].join(' · '),
                      ),
                      trailing: Text(
                        money(t.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onLongPress: () async {
                        if (await confirm(
                          context,
                          tr('ট্রান্সফার মুছবেন?', 'Delete transfer?'),
                          ok: tr('মুছুন', 'Delete'),
                          danger: true,
                        )) {
                          await ref.read(repoProvider).deleteTransfer(t.id);
                        }
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Wallet? w) async {
    final name = TextEditingController(text: w?.name ?? '');
    final opening = TextEditingController(text: w == null ? '' : paisaToPlain(w.openingBalance));
    var emoji = w?.emoji ?? '👛';
    var archived = w?.archived ?? false;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            w == null ? tr('নতুন ওয়ালেট', 'New wallet') : tr('ওয়ালেট এডিট', 'Edit wallet'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () async {
                      final e = await pickEmoji(ctx);
                      if (e != null) setState(() => emoji = e);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: tr('নাম (যেমন bKash)', 'Name (e.g. bKash)'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: opening,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: tr('শুরুর ব্যালেন্স ৳', 'Opening balance ৳'),
                ),
              ),
              if (w != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('লুকিয়ে রাখুন', 'Hide')),
                  value: archived,
                  onChanged: (v) => setState(() => archived = v),
                ),
            ],
          ),
          actions: [
            if (w != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: Text(tr('মুছুন', 'Delete')),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল', 'Cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(tr('সেভ', 'Save')),
            ),
          ],
        ),
      ),
    );
    final repo = ref.read(repoProvider);
    if (result == 'save' && name.text.trim().isNotEmpty) {
      final ob = parseMoney(opening.text) ?? 0;
      if (w == null) {
        await repo.addWallet(name.text, emoji, ob);
      } else {
        await repo.updateWallet(
          w.copyWith(name: name.text.trim(), emoji: emoji, openingBalance: ob, archived: archived),
        );
      }
    } else if (result == 'delete' && w != null) {
      final n = await repo.countWalletUse(w.id);
      if (!context.mounted) return;
      if (n > 0) {
        toast(
          context,
          tr(
            'এই ওয়ালেটে ${dg(n)}টি এন্ট্রি/ট্রান্সফার আছে — মুছতে না পারলে \'লুকিয়ে রাখুন\'',
            'This wallet has ${dg(n)} entries/transfers — use \'Hide\' instead of deleting',
          ),
        );
      } else if ((ref.read(walletsProvider).value?.length ?? 0) <= 1) {
        toast(context, tr('অন্তত একটি ওয়ালেট থাকতে হবে', 'You need at least one wallet'));
      } else {
        await repo.deleteWallet(w.id);
      }
    }
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref, List<Wallet> wallets) async {
    var from = wallets[0].id;
    var to = wallets[1].id;
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(tr('ট্রান্সফার', 'Transfer')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: from,
                decoration: InputDecoration(labelText: tr('থেকে', 'From')),
                items: [
                  for (final w in wallets)
                    DropdownMenuItem(value: w.id, child: Text('${w.emoji} ${w.name}')),
                ],
                onChanged: (v) => setState(() => from = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: to,
                decoration: InputDecoration(labelText: tr('তে', 'To')),
                items: [
                  for (final w in wallets)
                    DropdownMenuItem(value: w.id, child: Text('${w.emoji} ${w.name}')),
                ],
                onChanged: (v) => setState(() => to = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: tr('টাকা ৳', 'Amount ৳')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: InputDecoration(labelText: tr('নোট (ঐচ্ছিক)', 'Note (optional)')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('বাতিল', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('ট্রান্সফার', 'Transfer')),
            ),
          ],
        ),
      ),
    );
    final a = parseMoney(amount.text);
    if (ok != true || a == null || a <= 0) return;
    if (from == to) {
      if (context.mounted) {
        toast(context, tr('একই ওয়ালেটে ট্রান্সফার হয় না', 'Can\'t transfer to the same wallet'));
      }
      return;
    }
    await ref
        .read(repoProvider)
        .saveTransfer(from: from, to: to, amount: a, at: DateTime.now(), note: note.text);
  }
}
