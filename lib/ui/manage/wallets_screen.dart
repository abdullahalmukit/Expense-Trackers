import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import '../widgets/emoji_pick.dart';

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
      appBar: AppBar(title: const Text('ওয়ালেট')),
      floatingActionButton: fin.wallets.where((w) => !w.archived).length >= 2
          ? FloatingActionButton.extended(
              onPressed: () => _transfer(context, ref, fin.wallets.where((w) => !w.archived).toList()),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('ট্রান্সফার'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Card(
            child: ListTile(
              title: const Text('সব ওয়ালেটে মোট'),
              trailing: Text(money(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final w in fin.wallets)
                  ListTile(
                    leading: Text(w.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(w.name + (w.archived ? ' (লুকানো)' : '')),
                    subtitle: Text('শুরুর ব্যালেন্স ${money(w.openingBalance)}'),
                    trailing: Text(money(bal[w.id] ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                    onTap: () => _edit(context, ref, w),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('নতুন ওয়ালেট'),
                  onTap: () => _edit(context, ref, null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'ট্রান্সফার খরচ বা জমা হিসেবে গোনা হয় না। প্রথম ওয়ালেটের শুরুর ব্যালেন্সই অ্যাপ শুরুর সময় আপনার হাতে থাকা টাকা।',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
          ),
          if (transfers.isNotEmpty)
            SectionCard(
              title: 'ট্রান্সফার',
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Column(
                children: [
                  for (final t in transfers)
                    ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: Text(
                        '${fin.walletById[t.fromWalletId]?.name ?? '?'} → ${fin.walletById[t.toWalletId]?.name ?? '?'}',
                      ),
                      subtitle: Text([dateTimeLabel(t.occurredAt), if (t.note.isNotEmpty) t.note].join(' · ')),
                      trailing: Text(money(t.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                      onLongPress: () async {
                        if (await confirm(context, 'ট্রান্সফার মুছবেন?', ok: 'মুছুন', danger: true)) {
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
          title: Text(w == null ? 'নতুন ওয়ালেট' : 'ওয়ালেট এডিট'),
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
                      decoration: const InputDecoration(labelText: 'নাম (যেমন bKash)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: opening,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'শুরুর ব্যালেন্স ৳'),
              ),
              if (w != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('লুকিয়ে রাখুন'),
                  value: archived,
                  onChanged: (v) => setState(() => archived = v),
                ),
            ],
          ),
          actions: [
            if (w != null)
              TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('মুছুন')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('সেভ')),
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
        await repo.updateWallet(w.copyWith(name: name.text.trim(), emoji: emoji, openingBalance: ob, archived: archived));
      }
    } else if (result == 'delete' && w != null) {
      final n = await repo.countWalletUse(w.id);
      if (!context.mounted) return;
      if (n > 0) {
        toast(context, 'এই ওয়ালেটে ${dg(n)}টি এন্ট্রি/ট্রান্সফার আছে — মুছতে না পারলে \'লুকিয়ে রাখুন\'');
      } else if ((ref.read(walletsProvider).value?.length ?? 0) <= 1) {
        toast(context, 'অন্তত একটি ওয়ালেট থাকতে হবে');
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
          title: const Text('ট্রান্সফার'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: from,
                decoration: const InputDecoration(labelText: 'থেকে'),
                items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text('${w.emoji} ${w.name}'))],
                onChanged: (v) => setState(() => from = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: to,
                decoration: const InputDecoration(labelText: 'তে'),
                items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text('${w.emoji} ${w.name}'))],
                onChanged: (v) => setState(() => to = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'টাকা ৳'),
              ),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ট্রান্সফার')),
          ],
        ),
      ),
    );
    final a = parseMoney(amount.text);
    if (ok != true || a == null || a <= 0) return;
    if (from == to) {
      if (context.mounted) toast(context, 'একই ওয়ালেটে ট্রান্সফার হয় না');
      return;
    }
    await ref.read(repoProvider).saveTransfer(from: from, to: to, amount: a, at: DateTime.now(), note: note.text);
  }
}
