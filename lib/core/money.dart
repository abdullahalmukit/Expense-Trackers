/// টাকা পয়সায় পূর্ণসংখ্যা হিসেবে রাখা হয় (১২.৫০ ৳ = 1250)।
/// এই ফাইলে সংখ্যা/টাকা ফরম্যাটিং আর বাংলা সংখ্যা রূপান্তর।
library;

import 'i18n.dart';

const List<String> _bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

/// অ্যাপ জুড়ে বাংলা সংখ্যা দেখানো হবে কিনা (সেটিংস থেকে সেট হয়)।
class NumFmt {
  static bool bengali = true;
}

String toBnDigits(String s) => s.replaceAllMapped(RegExp(r'[0-9]'), (m) => _bn[int.parse(m[0]!)]);

String toEnDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final i = _bn.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

/// সেটিংস অনুযায়ী সংখ্যা রূপান্তর।
String dg(Object s) => NumFmt.bengali ? toBnDigits('$s') : '$s';

/// ভারতীয়/বাংলাদেশি গ্রুপিং: 1234567 → 12,34,567
String groupIndian(int n) {
  final neg = n < 0;
  var s = n.abs().toString();
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last3';
  }
  return neg ? '-$s' : s;
}

/// পয়সা → "৳১,২৫০" বা "৳১২.৫০"।
String money(int paisa, {bool symbol = true, bool signed = false}) {
  final neg = paisa < 0;
  final abs = paisa.abs();
  final taka = abs ~/ 100;
  final p = abs % 100;
  var s = groupIndian(taka);
  if (p != 0) s = '$s.${p.toString().padLeft(2, '0')}';
  s = dg(s);
  final sign = neg ? '-' : (signed && paisa > 0 ? '+' : '');
  return symbol ? '$sign৳$s' : '$sign$s';
}

/// চার্টের জন্য ছোট রূপ: ১.২হা, ৩.৪লা (English: 1.2K, 3.4L)
String moneyCompact(int paisa) {
  final taka = paisa / 100;
  final a = taka.abs();
  String s;
  if (a >= 10000000) {
    s = '${_trim(taka / 10000000)}${tr('কো', 'Cr')}';
  } else if (a >= 100000) {
    s = '${_trim(taka / 100000)}${tr('লা', 'L')}';
  } else if (a >= 1000) {
    s = '${_trim(taka / 1000)}${tr('হা', 'K')}';
  } else {
    s = taka.round().toString();
  }
  return dg(s);
}

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// ব্যবহারকারীর লেখা টাকা (বাংলা/ইংরেজি সংখ্যা, কমা সহ) → পয়সা।
int? parseMoney(String input) {
  final s = toEnDigits(input).replaceAll(',', '').replaceAll('৳', '').trim();
  if (s.isEmpty) return null;
  final v = double.tryParse(s);
  if (v == null) return null;
  return (v * 100).round();
}

/// পয়সা → সম্পাদনার জন্য সাধারণ স্ট্রিং ("1250.5")
String paisaToPlain(int paisa) {
  final t = paisa ~/ 100;
  final p = paisa % 100;
  if (p == 0) return '$t';
  final ps = p.toString().padLeft(2, '0');
  return '$t.${ps.endsWith('0') ? ps[0] : ps}';
}

String percent(double v) => '${dg(v.round())}%';
