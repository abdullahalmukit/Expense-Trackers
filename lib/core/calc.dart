import 'money.dart';

/// ছোট ক্যালকুলেটর: "১২০+৪৫×২" → পয়সা। + − × ÷ এবং দশমিক সমর্থন করে।
/// ভুল এক্সপ্রেশনে null ফেরত দেয়।
int? evaluateExpression(String raw) {
  final s = toEnDigits(raw)
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAll(',', '')
      .replaceAll(' ', '');
  if (s.isEmpty) return null;
  final tokens = <String>[];
  final num = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if ('0123456789.'.contains(c)) {
      num.write(c);
    } else if ('+-*/'.contains(c)) {
      if (num.isEmpty) {
        // শুরুতে বা অপারেটরের পরে '-' হলে ঋণাত্মক সংখ্যা
        if (c == '-' && (tokens.isEmpty || '+-*/'.contains(tokens.last))) {
          num.write('-');
          continue;
        }
        // শেষে ঝুলে থাকা অপারেটর উপেক্ষা
        if (i == s.length - 1) break;
        return null;
      }
      tokens.add(num.toString());
      num.clear();
      tokens.add(c);
    } else {
      return null;
    }
  }
  if (num.isNotEmpty) tokens.add(num.toString());
  if (tokens.isNotEmpty && '+-*/'.contains(tokens.last)) tokens.removeLast();
  if (tokens.isEmpty) return null;

  // প্রথমে * আর /
  final stack = <double>[];
  final ops = <String>[];
  double? parse(String t) => double.tryParse(t);
  final first = parse(tokens[0]);
  if (first == null) return null;
  stack.add(first);
  for (var i = 1; i < tokens.length; i += 2) {
    if (i + 1 >= tokens.length) break;
    final op = tokens[i];
    final v = parse(tokens[i + 1]);
    if (v == null) return null;
    if (op == '*') {
      stack[stack.length - 1] = stack.last * v;
    } else if (op == '/') {
      if (v == 0) return null;
      stack[stack.length - 1] = stack.last / v;
    } else {
      ops.add(op);
      stack.add(v);
    }
  }
  var result = stack[0];
  for (var i = 0; i < ops.length; i++) {
    result = ops[i] == '+' ? result + stack[i + 1] : result - stack[i + 1];
  }
  if (result.isNaN || result.isInfinite) return null;
  return (result * 100).round();
}

bool hasOperator(String s) => RegExp(r'[+\-×÷*/−]').hasMatch(s.length > 1 ? s.substring(1) : '');
