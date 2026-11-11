import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import '../widgets/emoji_pick.dart';

/// নতুন ক্যাটাগরি বা এডিট — নাম, ইমোজি, রং আর ধরন। নতুন হলে id ফেরত দেয়।
Future<int?> showCategoryEditor(
  BuildContext context,
  WidgetRef ref, {
  Cat? cat,
  int kind = 0,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _CategoryEditor(cat: cat, kind: kind),
  );
}

class _CategoryEditor extends ConsumerStatefulWidget {
  const _CategoryEditor({this.cat, required this.kind});
  final Cat? cat;
  final int kind;
  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.cat?.name ?? '');
  late String _emoji = widget.cat?.emoji ?? '🏷️';
  late int _color = widget.cat?.color ?? AppColors.palette[7].toARGB32();
  late int _kind = widget.cat?.kind ?? widget.kind;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'নাম লিখুন');
      return;
    }
    final repo = ref.read(repoProvider);
    final c = widget.cat;
    if (c == null) {
      final id = await repo.addCategory(
        name: name,
        emoji: _emoji,
        color: _color,
        kind: _kind,
      );
      if (mounted) Navigator.pop(context, id);
    } else {
      await repo.updateCategory(
        c.copyWith(name: name, emoji: _emoji, color: _color),
      );
      if (mounted) Navigator.pop(context, c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.cat != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing ? 'ক্যাটাগরি এডিট' : 'নতুন ক্যাটাগরি',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  final e = await pickEmoji(context);
                  if (e != null) setState(() => _emoji = e);
                },
                child: CatAvatar(emoji: _emoji, color: Color(_color), size: 60),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: !editing,
                  decoration: const InputDecoration(labelText: 'নাম'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ইমোজিতে ট্যাপ করে বদলান',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in AppColors.palette)
                GestureDetector(
                  onTap: () => setState(() => _color = c.toARGB32()),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _color == c.toARGB32()
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!editing)
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('খরচ')),
                ButtonSegment(value: 1, label: Text('জমা')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('সেভ')),
        ],
      ),
    );
  }
}
