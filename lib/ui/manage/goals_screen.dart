import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import '../widgets/emoji_pick.dart';

/// সঞ্চয়ের লক্ষ্য — যেমন 'ল্যাপটপ', প্রগ্রেস রিং সহ
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    return Scaffold(
      appBar: AppBar(title: const Text('সঞ্চয়ের লক্ষ্য')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('নতুন লক্ষ্য'),
      ),
      body: goals.isEmpty
          ? const EmptyState(emoji: '🎯', title: 'কোনো লক্ষ্য নেই', subtitle: 'যেমন \'ল্যাপটপ\' — কত জমলো তা রিংয়ে দেখাবে')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                for (final g in goals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _edit(context, ref, g),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              GoalRing(goal: g, size: 72, showLabel: false),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${g.emoji} ${g.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                    Text('${money(g.saved)} / ${money(g.target)}'),
                                    if (g.deadline != null)
                                      Text(
                                        'লক্ষ্য তারিখ ${dayLabel(g.deadline!, withYear: true)}',
                                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'জমা যোগ',
                                onPressed: () => _add(context, ref, g),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, Goal g) async {
    final c = TextEditingController();
    var withdraw = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('${g.emoji} ${g.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('জমা করলাম')),
                  ButtonSegment(value: true, label: Text('তুলে নিলাম')),
                ],
                selected: {withdraw},
                onSelectionChanged: (s) => setState(() => withdraw = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'টাকা ৳'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সেভ')),
          ],
        ),
      ),
    );
    final v = parseMoney(c.text);
    if (ok != true || v == null) return;
    await ref.read(repoProvider).updateGoal(g.copyWith(saved: math.max(0, g.saved + (withdraw ? -v : v))));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Goal? g) async {
    final name = TextEditingController(text: g?.name ?? '');
    final target = TextEditingController(text: g == null ? '' : paisaToPlain(g.target));
    var emoji = g?.emoji ?? '🎯';
    var color = g?.color ?? AppColors.palette[5].toARGB32();
    DateTime? deadline = g?.deadline;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(g == null ? 'নতুন লক্ষ্য' : 'লক্ষ্য এডিট'),
          content: SingleChildScrollView(
            child: Column(
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
                    Expanded(child: TextField(controller: name, decoration: const InputDecoration(labelText: 'নাম'))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'লক্ষ্য ৳'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in AppColors.palette.take(10))
                      GestureDetector(
                        onTap: () => setState(() => color = c.toARGB32()),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: c,
                          child: color == c.toARGB32() ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(deadline == null ? 'লক্ষ্য তারিখ (ঐচ্ছিক)' : dayLabel(deadline!, withYear: true)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: deadline ?? now.add(const Duration(days: 90)),
                      firstDate: now.subtract(const Duration(days: 365)),
                      lastDate: DateTime(now.year + 10),
                    );
                    if (d != null) setState(() => deadline = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (g != null) TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('মুছুন')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('সেভ')),
          ],
        ),
      ),
    );
    final repo = ref.read(repoProvider);
    final t = parseMoney(target.text);
    if (r == 'save' && name.text.trim().isNotEmpty && t != null && t > 0) {
      if (g == null) {
        await repo.addGoal(name.text, emoji, color, t, deadline);
      } else {
        await repo.updateGoal(g.copyWith(name: name.text.trim(), emoji: emoji, color: color, target: t, deadline: Value(deadline)));
      }
    } else if (r == 'delete' && g != null) {
      if (context.mounted && await confirm(context, 'লক্ষ্য মুছবেন?', ok: 'মুছুন', danger: true)) {
        await repo.deleteGoal(g.id);
      }
    }
  }
}

class GoalRing extends StatelessWidget {
  const GoalRing({super.key, required this.goal, this.size = 76, this.showLabel = true});
  final Goal goal;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final p = goal.target <= 0 ? 0.0 : (goal.saved / goal.target).clamp(0.0, 1.0);
    final c = Color(goal.color);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: p),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      color: c,
                      backgroundColor: c.withValues(alpha: .15),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(goal.emoji, style: TextStyle(fontSize: size * .26)),
                    Text(percent(p * 100), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: size + 10,
              child: Text(goal.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
