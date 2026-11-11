import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/calc.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/repo.dart';
import '../../domain/finance.dart';
import '../../providers.dart';
import '../manage/category_editor.dart';
import '../widgets/common.dart';
import 'numpad.dart';
import '../../core/i18n.dart';

/// এন্ট্রি যোগ/এডিটের বটম শিট।
Future<void> showEntrySheet(
  BuildContext context, {
  Txn? edit,
  int? type,
  int? debtAction,
  int? personId,
  int? amount,
  int? categoryId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .96,
      child: EntrySheet(
        edit: edit,
        initialType: type,
        debtAction: debtAction,
        personId: personId,
        amount: amount,
        categoryId: categoryId,
      ),
    ),
  );
}

class EntrySheet extends ConsumerStatefulWidget {
  const EntrySheet({
    super.key,
    this.edit,
    this.initialType,
    this.debtAction,
    this.personId,
    this.amount,
    this.categoryId,
  });
  final Txn? edit;
  final int? initialType;
  final int? debtAction;
  final int? personId;
  final int? amount;
  final int? categoryId;

  @override
  ConsumerState<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<EntrySheet> with SingleTickerProviderStateMixin {
  late int _type;
  String _expr = '';
  int? _categoryId;
  int? _debtAction;
  int? _personId;
  String? _newPerson;
  int? _walletId;
  late DateTime _at;
  DateTime? _due;
  final _note = TextEditingController();
  final _purpose = TextEditingController();
  String? _photo;
  bool _details = false;
  bool _saving = false;
  int _savedCount = 0;
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _type = e.type;
      _expr = paisaToPlain(e.amount);
      _categoryId = e.categoryId;
      _debtAction = e.debtAction;
      _personId = e.personId;
      _walletId = e.walletId;
      _at = e.occurredAt;
      _due = e.dueDate;
      _note.text = e.note;
      _purpose.text = e.purpose;
      _photo = e.photoPath;
      _details = e.note.isNotEmpty || e.purpose.isNotEmpty || e.photoPath != null;
    } else {
      _debtAction = widget.debtAction;
      _type = widget.debtAction != null
          ? DebtAction.typeOf(widget.debtAction!)
          : (widget.initialType ?? TxType.expense);
      _personId = widget.personId;
      _categoryId = widget.categoryId;
      if (widget.amount != null) _expr = paisaToPlain(widget.amount!);
      _at = DateTime.now();
      if (_debtAction != null) _resolveDebtCategory();
    }
  }

  Future<void> _resolveDebtCategory() async {
    final id = await ref.read(repoProvider).ensureDebtCategory(_type);
    if (mounted) setState(() => _categoryId = id);
  }

  @override
  void dispose() {
    _note.dispose();
    _purpose.dispose();
    _check.dispose();
    super.dispose();
  }

  int? get _amount => evaluateExpression(_expr);

  void _setType(int t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      final fin = ref.read(financeProvider);
      final cat = fin.catById[_categoryId];
      if (cat != null && cat.isDebt) {
        // ধার ক্যাটাগরি অন্য ধরনেও থাকে
        final other = fin.cats.where((c) => c.isDebt && c.kind == t).firstOrNull;
        _categoryId = other?.id;
        _debtAction = DebtAction.forType(t).first;
        if (other == null) _resolveDebtCategory();
      } else {
        _categoryId = null;
        _debtAction = null;
      }
    });
  }

  void _selectCategory(Cat c) {
    HapticFeedback.selectionClick();
    setState(() {
      _categoryId = c.id;
      if (c.isDebt) {
        _debtAction ??= DebtAction.forType(_type).first;
        if (DebtAction.typeOf(_debtAction!) != _type) {
          _debtAction = DebtAction.forType(_type).first;
        }
      } else {
        _debtAction = null;
      }
    });
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    setState(() {
      _at = DateTime(d.year, d.month, d.day, t?.hour ?? _at.hour, t?.minute ?? _at.minute);
    });
  }

  void _quickDay(int daysAgo) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day - daysAgo);
    setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
  }

  Future<void> _pickPhoto(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 75);
      if (x == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final rec = Directory(p.join(dir.path, 'receipts'));
      await rec.create(recursive: true);
      final dest = p.join(
        rec.path,
        '${newId()}${p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path)}',
      );
      await File(x.path).copy(dest);
      setState(() => _photo = dest);
    } catch (e) {
      if (mounted) toast(context, tr('ছবি নেওয়া যায়নি', 'Could not get the photo'));
    }
  }

  Future<void> _delete() async {
    final e = widget.edit!;
    if (!await confirm(
      context,
      tr('এন্ট্রি মুছবেন?', 'Delete entry?'),
      ok: tr('মুছুন', 'Delete'),
      danger: true,
    )) {
      return;
    }
    await ref.read(repoProvider).deleteTxn(e.id);
    await ref.read(effectsProvider).afterDelete(e.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save({bool another = false}) async {
    if (_saving) return;
    final amount = _amount;
    if (amount == null || amount <= 0) {
      toast(context, tr('টাকার অংক লিখুন', 'Enter an amount'));
      return;
    }
    if (_categoryId == null) {
      toast(context, tr('একটি ক্যাটাগরি বাছুন', 'Pick a category'));
      return;
    }
    final repo = ref.read(repoProvider);
    final fin = ref.read(financeProvider);
    final cat = fin.catById[_categoryId];
    final isDebt = cat?.isDebt ?? false;
    int? personId = _personId;
    if (isDebt) {
      if ((_newPerson ?? '').trim().isNotEmpty) {
        personId = await repo.findOrCreatePerson(_newPerson!);
      }
      if (personId == null) {
        if (mounted) {
          toast(
            context,
            tr(
              'কার সাথে ধার — ব্যক্তি বাছুন বা নাম লিখুন',
              'Who is the debt with? Pick a person or type a name',
            ),
          );
        }
        return;
      }
    }
    setState(() => _saving = true);
    final wallets = fin.wallets.where((w) => !w.archived).toList();
    final txn = await repo.saveTxn(
      id: widget.edit?.id,
      type: _type,
      amount: amount,
      categoryId: _categoryId!,
      debtAction: isDebt ? _debtAction : null,
      personId: isDebt ? personId : null,
      walletId: _walletId ?? (wallets.isEmpty ? null : wallets.first.id),
      occurredAt: _at,
      note: _note.text,
      purpose: _purpose.text,
      photoPath: _photo,
      dueDate: isDebt && (_debtAction == DebtAction.borrow || _debtAction == DebtAction.lend)
          ? _due
          : null,
    );
    HapticFeedback.mediumImpact();
    ref.read(effectsProvider).afterSave(txn);
    await _check.forward(from: 0);
    if (!mounted) return;
    if (another) {
      setState(() {
        _saving = false;
        _savedCount++;
        _expr = '';
        _note.clear();
        _purpose.clear();
        _photo = null;
        _due = null;
        _newPerson = null;
      });
      _check.reset();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fin = ref.watch(financeProvider);
    final scheme = Theme.of(context).colorScheme;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final color = AppColors.forType(_type);
    final amount = _amount;
    final selectedCat = fin.catById[_categoryId];
    final isDebt = selectedCat?.isDebt ?? false;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<int>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: color.withValues(alpha: .18),
                          selectedForegroundColor: color,
                        ),
                        segments: [
                          ButtonSegment(
                            value: TxType.expense,
                            label: Text(tr('খরচ', 'Expense')),
                            icon: Icon(Icons.north_east),
                          ),
                          ButtonSegment(
                            value: TxType.income,
                            label: Text(tr('জমা', 'Income')),
                            icon: Icon(Icons.south_west),
                          ),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) => _setType(s.first),
                      ),
                    ),
                    if (widget.edit != null)
                      IconButton(
                        tooltip: tr('মুছুন', 'Delete'),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
              // বড় অংকে টাকা
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  children: [
                    FittedBox(
                      child: Text(
                        _expr.isEmpty ? '৳${dg(0)}' : '৳${dg(_expr)}',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: _expr.isEmpty ? scheme.outline : color,
                        ),
                      ),
                    ),
                    if (hasOperator(_expr))
                      Text(
                        amount == null ? tr('ভুল হিসাব', 'Invalid') : '= ${money(amount)}',
                        style: TextStyle(color: scheme.outline, fontWeight: FontWeight.w600),
                      ),
                    if (_savedCount > 0)
                      Text(
                        tr('${dg(_savedCount)}টি এন্ট্রি সেভ হয়েছে', '${dg(_savedCount)} saved'),
                        style: TextStyle(color: AppColors.income, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  children: [
                    _CategoryGrid(
                      fin: fin,
                      type: _type,
                      selected: _categoryId,
                      onSelect: _selectCategory,
                      onNew: () async {
                        final id = await showCategoryEditor(context, ref, kind: _type);
                        if (id != null) setState(() => _categoryId = id);
                      },
                    ),
                    if (isDebt) ...[
                      const SizedBox(height: 8),
                      _DebtSection(
                        fin: fin,
                        type: _type,
                        action: _debtAction ?? DebtAction.forType(_type).first,
                        personId: _personId,
                        newPerson: _newPerson,
                        due: _due,
                        onAction: (a) => setState(() => _debtAction = a),
                        onPerson: (id, remaining) => setState(() {
                          _personId = id;
                          _newPerson = null;
                          if (_expr.isEmpty && remaining != null && remaining > 0) {
                            _expr = paisaToPlain(remaining);
                          }
                        }),
                        onNewPerson: (n) => setState(() {
                          _newPerson = n;
                          _personId = null;
                        }),
                        onDue: (d) => setState(() => _due = d),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.event, size: 18),
                          label: Text(dateTimeLabel(_at)),
                          onPressed: _pickDateTime,
                        ),
                        ChoiceChip(
                          label: Text(tr('আজ', 'Today')),
                          selected: sameDay(_at, DateTime.now()),
                          onSelected: (_) => _quickDay(0),
                        ),
                        ChoiceChip(
                          label: Text(tr('গতকাল', 'Yesterday')),
                          selected: sameDay(_at, DateTime.now().subtract(const Duration(days: 1))),
                          onSelected: (_) => _quickDay(1),
                        ),
                      ],
                    ),
                    if (fin.wallets.where((w) => !w.archived).length > 1) ...[
                      const SizedBox(height: 4),
                      _WalletChips(
                        wallets: fin.wallets.where((w) => !w.archived).toList(),
                        selected: _walletId,
                        onSelect: (id) => setState(() => _walletId = id),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Card(
                      color: scheme.surfaceContainerHighest.withValues(alpha: .4),
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.notes),
                            title: Text(tr('বিবরণ, উদ্দেশ্য ও রসিদ', 'Note, purpose & receipt')),
                            subtitle: (_note.text.isNotEmpty || _purpose.text.isNotEmpty)
                                ? Text(
                                    [
                                      _note.text,
                                      _purpose.text,
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(
                                    tr('ঐচ্ছিক · #ট্যাগ লেখা যায়', 'Optional · #tags supported'),
                                  ),
                            trailing: Icon(_details ? Icons.expand_less : Icons.expand_more),
                            onTap: () => setState(() => _details = !_details),
                          ),
                          if (_details)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Column(
                                children: [
                                  _SuggestField(
                                    controller: _note,
                                    label: tr('বিবরণ', 'Note'),
                                    suggestions: _suggestions(fin, (t) => t.note),
                                  ),
                                  const SizedBox(height: 8),
                                  _SuggestField(
                                    controller: _purpose,
                                    label: tr('উদ্দেশ্য', 'Purpose'),
                                    suggestions: _suggestions(fin, (t) => t.purpose),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (_photo != null) ...[
                                        GestureDetector(
                                          onTap: () => showPhoto(context, _photo!),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.file(
                                              File(_photo!),
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(Icons.broken_image),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => setState(() => _photo = null),
                                          icon: const Icon(Icons.close),
                                        ),
                                      ],
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => _pickPhoto(ImageSource.camera),
                                        icon: const Icon(Icons.photo_camera_outlined),
                                        label: Text(tr('ছবি', 'Camera')),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _pickPhoto(ImageSource.gallery),
                                        icon: const Icon(Icons.photo_outlined),
                                        label: Text(tr('গ্যালারি', 'Gallery')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!keyboardOpen)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: NumPad(
                    onKey: (k) => setState(() => _expr = applyKey(_expr, k)),
                    onClear: () => setState(() => _expr = ''),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Row(
                    children: [
                      if (widget.edit == null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => _save(another: true),
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                            child: Text(tr('সেভ ও আরেকটা', 'Save & add another')),
                          ),
                        ),
                      if (widget.edit == null) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: color,
                          ),
                          icon: const Icon(Icons.check),
                          label: Text(
                            widget.edit == null ? tr('সেভ', 'Save') : tr('আপডেট', 'Update'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // সেভের চেকমার্ক অ্যানিমেশন
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _check,
            builder: (context, _) {
              final v = _check.value;
              if (v == 0) return const SizedBox.shrink();
              final scale = Curves.elasticOut.transform(v.clamp(0, 1));
              return Center(
                child: Opacity(
                  opacity: v < .8 ? 1 : (1 - (v - .8) * 5).clamp(0, 1),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: color.withValues(alpha: .4), blurRadius: 24)],
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 64),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<String> _suggestions(FinanceData fin, String Function(Txn) f) {
    final seen = <String>{};
    for (final t in fin.txns) {
      final s = f(t).trim();
      if (s.isNotEmpty) seen.add(s);
      if (seen.length >= 200) break;
    }
    return seen.toList();
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.fin,
    required this.type,
    required this.selected,
    required this.onSelect,
    required this.onNew,
  });
  final FinanceData fin;
  final int type;
  final int? selected;
  final ValueChanged<Cat> onSelect;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final usage = fin.usageCounts();
    final cats = fin.cats.where((c) => c.kind == type && !c.archived).toList()
      ..sort((a, b) {
        final u = (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0);
        return u != 0 ? u : a.sortOrder.compareTo(b.sortOrder);
      });
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: .9,
      children: [
        for (final c in cats)
          _Tile(
            emoji: c.emoji,
            label: c.name,
            color: Color(c.color),
            selected: c.id == selected,
            onTap: () => onSelect(c),
          ),
        _Tile(
          emoji: '',
          icon: Icons.add_circle_outline,
          label: tr('নতুন', 'New'),
          color: scheme.outline,
          selected: false,
          onTap: onNew,
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    this.icon,
    required this.emoji,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final IconData? icon;
  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: .22) : color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? color : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 30, color: color)
            else
              Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtSection extends StatefulWidget {
  const _DebtSection({
    required this.fin,
    required this.type,
    required this.action,
    required this.personId,
    required this.newPerson,
    required this.due,
    required this.onAction,
    required this.onPerson,
    required this.onNewPerson,
    required this.onDue,
  });
  final FinanceData fin;
  final int type;
  final int action;
  final int? personId;
  final String? newPerson;
  final DateTime? due;
  final ValueChanged<int> onAction;
  final void Function(int id, int? remaining) onPerson;
  final ValueChanged<String?> onNewPerson;
  final ValueChanged<DateTime?> onDue;

  @override
  State<_DebtSection> createState() => _DebtSectionState();
}

class _DebtSectionState extends State<_DebtSection> {
  bool _typing = false;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = DebtAction.forType(widget.type);
    final debts = {for (final d in widget.fin.debts()) d.person.id: d};
    final settling = widget.action == DebtAction.repay || widget.action == DebtAction.collect;
    int? remainingOf(int pid) {
      final d = debts[pid];
      if (d == null) return null;
      return widget.action == DebtAction.repay
          ? d.payable
          : (widget.action == DebtAction.collect ? d.receivable : null);
    }

    final persons = [...widget.fin.persons];
    if (settling) {
      // যাদের বাকি আছে তারা আগে
      persons.sort((a, b) => (remainingOf(b.id) ?? 0).compareTo(remainingOf(a.id) ?? 0));
    }
    return Card(
      color: AppColors.debt.withValues(alpha: .07),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.debt.withValues(alpha: .2),
                selectedForegroundColor: AppColors.debt,
              ),
              segments: [
                for (final a in actions) ButtonSegment(value: a, label: Text(DebtAction.label(a))),
              ],
              selected: {actions.contains(widget.action) ? widget.action : actions.first},
              onSelectionChanged: (s) => widget.onAction(s.first),
            ),
            const SizedBox(height: 10),
            Text(tr('কার সাথে?', 'With whom?'), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final p in persons)
                  ChoiceChip(
                    label: Text(
                      (remainingOf(p.id) ?? 0) > 0
                          ? '${p.name} · ${money(remainingOf(p.id)!)}'
                          : p.name,
                    ),
                    selected: widget.personId == p.id,
                    onSelected: (_) {
                      setState(() => _typing = false);
                      widget.onPerson(p.id, settling ? remainingOf(p.id) : null);
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.person_add_alt, size: 18),
                  label: Text(tr('নতুন নাম', 'New name')),
                  onPressed: () => setState(() => _typing = true),
                ),
              ],
            ),
            if (_typing || (widget.newPerson ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tr('ব্যক্তির নাম', 'Person\'s name'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: widget.onNewPerson,
                ),
              ),
            if (!settling)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InputChip(
                    avatar: const Icon(Icons.alarm, size: 18),
                    label: Text(
                      widget.due == null
                          ? (widget.action == DebtAction.borrow
                                ? tr('শোধের তারিখ (ঐচ্ছিক)', 'Repay by (optional)')
                                : tr('ফেরতের তারিখ (ঐচ্ছিক)', 'Return by (optional)'))
                          : tr(
                              'রিমাইন্ডার: ${dayLabel(widget.due!)}',
                              'Reminder: ${dayLabel(widget.due!)}',
                            ),
                    ),
                    onDeleted: widget.due == null ? null : () => widget.onDue(null),
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        initialDate: widget.due ?? now.add(const Duration(days: 7)),
                        firstDate: now,
                        lastDate: DateTime(now.year + 5),
                      );
                      if (d != null) widget.onDue(d);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WalletChips extends StatelessWidget {
  const _WalletChips({required this.wallets, required this.selected, required this.onSelect});
  final List<Wallet> wallets;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final sel = selected ?? wallets.first.id;
    return Wrap(
      spacing: 6,
      children: [
        for (final w in wallets)
          ChoiceChip(
            label: Text('${w.emoji} ${w.name}'),
            selected: w.id == sel,
            onSelected: (_) => onSelect(w.id),
          ),
      ],
    );
  }
}

class _SuggestField extends StatefulWidget {
  const _SuggestField({required this.controller, required this.label, required this.suggestions});
  final TextEditingController controller;
  final String label;
  final List<String> suggestions;

  @override
  State<_SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<_SuggestField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const [];
        return widget.suggestions.where((s) => s.toLowerCase().contains(q) && s != v.text).take(5);
      },
      fieldViewBuilder: (context, c, focus, onSubmit) => TextField(
        controller: c,
        focusNode: focus,
        decoration: InputDecoration(labelText: widget.label),
        textInputAction: TextInputAction.done,
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(dense: true, title: Text(o), onTap: () => onSelected(o)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
