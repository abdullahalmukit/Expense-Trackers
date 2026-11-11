import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';

/// নিজস্ব নাম্বার প্যাড, সাথে + − × ÷ ক্যালকুলেটর
class NumPad extends StatelessWidget {
  const NumPad({super.key, required this.onKey, required this.onClear});
  final ValueChanged<String> onKey;
  final VoidCallback onClear;

  static const _rows = [
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '−'],
    ['.', '0', '⌫', '+'],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final k in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Material(
                      color: '+−×÷'.contains(k)
                          ? scheme.secondaryContainer
                          : scheme.surfaceContainerHighest.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onKey(k);
                        },
                        onLongPress: k == '⌫' ? onClear : null,
                        child: SizedBox(
                          height: 46,
                          child: Center(
                            child: k == '⌫'
                                ? const Icon(Icons.backspace_outlined, size: 20)
                                : Text(
                                    '0123456789'.contains(k) ? dg(k) : k,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// এক্সপ্রেশনে কী চাপলে নতুন এক্সপ্রেশন
String applyKey(String expr, String k) {
  const ops = '+−×÷';
  if (k == '⌫') return expr.isEmpty ? expr : expr.substring(0, expr.length - 1);
  if (ops.contains(k)) {
    if (expr.isEmpty) return expr;
    final last = expr[expr.length - 1];
    if (ops.contains(last) || last == '.') {
      return expr.substring(0, expr.length - 1) + k;
    }
    return expr + k;
  }
  // বর্তমান সংখ্যার অংশ
  final parts = expr.split(RegExp('[+−×÷]'));
  final current = parts.isEmpty ? '' : parts.last;
  if (k == '.') {
    if (current.contains('.')) return expr;
    return expr + (current.isEmpty ? '0.' : '.');
  }
  if (current.contains('.') && current.split('.').last.length >= 2) return expr;
  if (current == '0') return expr.substring(0, expr.length - 1) + k;
  if (current.replaceAll('.', '').length >= 10) return expr;
  return expr + k;
}
