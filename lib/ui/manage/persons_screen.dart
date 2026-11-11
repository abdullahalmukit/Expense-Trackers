import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../debt/person_screen.dart';
import '../widgets/common.dart';

class PersonsScreen extends ConsumerWidget {
  const PersonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final fin = ref.watch(financeProvider);
    final counts = <int, int>{};
    for (final t in fin.txns) {
      if (t.personId != null) counts[t.personId!] = (counts[t.personId!] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ব্যক্তি')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPersonEditor(context, ref, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('নতুন'),
      ),
      body: persons.isEmpty
          ? const EmptyState(emoji: '👥', title: 'কোনো ব্যক্তি নেই', subtitle: 'ধারের এন্ট্রিতে নাম লিখলে এখানে যোগ হবে')
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                for (final p in persons)
                  ListTile(
                    leading: CircleAvatar(child: Text(p.name.characters.first)),
                    title: Text(p.name),
                    subtitle: Text([
                      '${dg(counts[p.id] ?? 0)}টি এন্ট্রি',
                      if (p.phone.isNotEmpty) dg(p.phone),
                    ].join(' · ')),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonScreen(personId: p.id))),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') showPersonEditor(context, ref, p);
                        if (v == 'merge') _merge(context, ref, p, persons);
                        if (v == 'delete') _delete(context, ref, p);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('এডিট')),
                        PopupMenuItem(value: 'merge', child: Text('অন্য নামের সাথে একত্র করুন')),
                        PopupMenuItem(value: 'delete', child: Text('মুছুন')),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Person p) async {
    final repo = ref.read(repoProvider);
    final n = await repo.countTxnsOfPerson(p.id);
    if (!context.mounted) return;
    if (n > 0) {
      toast(context, '${p.name}-এর ${dg(n)}টি এন্ট্রি আছে — আগে সেগুলো মুছুন বা অন্য নামের সাথে একত্র করুন');
      return;
    }
    if (await confirm(context, '${p.name} মুছবেন?', ok: 'মুছুন', danger: true)) {
      await repo.deletePerson(p.id);
    }
  }

  Future<void> _merge(BuildContext context, WidgetRef ref, Person p, List<Person> all) async {
    final target = await showDialog<Person>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${p.name}-এর সব এন্ট্রি কার নামে যাবে?'),
        children: [
          for (final x in all.where((x) => x.id != p.id))
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, x), child: Text(x.name)),
        ],
      ),
    );
    if (target == null) return;
    await ref.read(repoProvider).mergePerson(p.id, target.id);
    if (context.mounted) toast(context, 'একত্র করা হয়েছে');
  }
}

Future<void> showPersonEditor(BuildContext context, WidgetRef ref, Person? p) async {
  final name = TextEditingController(text: p?.name ?? '');
  final phone = TextEditingController(text: p?.phone ?? '');
  final note = TextEditingController(text: p?.note ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(p == null ? 'নতুন ব্যক্তি' : 'এডিট'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'নাম')),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'ফোন (ঐচ্ছিক)'),
          ),
          const SizedBox(height: 10),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সেভ')),
      ],
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  final repo = ref.read(repoProvider);
  if (p == null) {
    final id = await repo.findOrCreatePerson(name.text);
    final created = await (repo.db.select(repo.db.persons)..where((x) => x.id.equals(id))).getSingle();
    await repo.updatePerson(created.copyWith(phone: phone.text.trim(), note: note.text.trim()));
  } else {
    await repo.updatePerson(p.copyWith(name: name.text.trim(), phone: phone.text.trim(), note: note.text.trim()));
  }
}
