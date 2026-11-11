import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../debt/person_screen.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

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
      appBar: AppBar(title: Text(tr('ব্যক্তি', 'People'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPersonEditor(context, ref, null),
        icon: Icon(Icons.person_add_alt),
        label: Text(tr('নতুন', 'New')),
      ),
      body: persons.isEmpty
          ? EmptyState(
              emoji: '👥',
              title: tr('কোনো ব্যক্তি নেই', 'No people'),
              subtitle: tr(
                'ধারের এন্ট্রিতে নাম লিখলে এখানে যোগ হবে',
                'Names you use in debt entries appear here',
              ),
            )
          : ListView(
              padding: EdgeInsets.only(bottom: 100),
              children: [
                for (final p in persons)
                  ListTile(
                    leading: CircleAvatar(child: Text(p.name.characters.first)),
                    title: Text(p.name),
                    subtitle: Text(
                      [
                        tr(
                          '${dg(counts[p.id] ?? 0)}টি এন্ট্রি',
                          '${dg(counts[p.id] ?? 0)} entries',
                        ),
                        if (p.phone.isNotEmpty) dg(p.phone),
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PersonScreen(personId: p.id)),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') showPersonEditor(context, ref, p);
                        if (v == 'merge') _merge(context, ref, p, persons);
                        if (v == 'delete') _delete(context, ref, p);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(tr('এডিট', 'Edit'))),
                        PopupMenuItem(
                          value: 'merge',
                          child: Text(tr('অন্য নামের সাথে একত্র করুন', 'Merge with another name')),
                        ),
                        PopupMenuItem(value: 'delete', child: Text(tr('মুছুন', 'Delete'))),
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
      toast(
        context,
        tr(
          '${p.name}-এর ${dg(n)}টি এন্ট্রি আছে — আগে সেগুলো মুছুন বা অন্য নামের সাথে একত্র করুন',
          '${p.name} has ${dg(n)} entries — delete them or merge with another name first',
        ),
      );
      return;
    }
    if (await confirm(
      context,
      tr('${p.name} মুছবেন?', 'Delete ${p.name}?'),
      ok: tr('মুছুন', 'Delete'),
      danger: true,
    )) {
      await repo.deletePerson(p.id);
    }
  }

  Future<void> _merge(BuildContext context, WidgetRef ref, Person p, List<Person> all) async {
    final target = await showDialog<Person>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          tr('${p.name}-এর সব এন্ট্রি কার নামে যাবে?', 'Move all of ${p.name}\'s entries to whom?'),
        ),
        children: [
          for (final x in all.where((x) => x.id != p.id))
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, x), child: Text(x.name)),
        ],
      ),
    );
    if (target == null) return;
    await ref.read(repoProvider).mergePerson(p.id, target.id);
    if (context.mounted) toast(context, tr('একত্র করা হয়েছে', 'Merged'));
  }
}

Future<void> showPersonEditor(BuildContext context, WidgetRef ref, Person? p) async {
  final name = TextEditingController(text: p?.name ?? '');
  final phone = TextEditingController(text: p?.phone ?? '');
  final note = TextEditingController(text: p?.note ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(p == null ? tr('নতুন ব্যক্তি', 'New person') : tr('এডিট', 'Edit')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: InputDecoration(labelText: tr('নাম', 'Name')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tr('ফোন (ঐচ্ছিক)', 'Phone (optional)')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: note,
            decoration: InputDecoration(labelText: tr('নোট (ঐচ্ছিক)', 'Note (optional)')),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('বাতিল', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('সেভ', 'Save'))),
      ],
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  final repo = ref.read(repoProvider);
  if (p == null) {
    final id = await repo.findOrCreatePerson(name.text);
    final created = await (repo.db.select(
      repo.db.persons,
    )..where((x) => x.id.equals(id))).getSingle();
    await repo.updatePerson(created.copyWith(phone: phone.text.trim(), note: note.text.trim()));
  } else {
    await repo.updatePerson(
      p.copyWith(name: name.text.trim(), phone: phone.text.trim(), note: note.text.trim()),
    );
  }
}
