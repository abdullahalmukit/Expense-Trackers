import 'package:flutter_test/flutter_test.dart';
import 'package:takar_khata/core/calc.dart';
import 'package:takar_khata/core/dates.dart';
import 'package:takar_khata/core/money.dart';
import 'package:takar_khata/ui/entry/numpad.dart';

void main() {
  setUp(() => NumFmt.bengali = true);

  test('টাকা ফরম্যাট — বাংলা সংখ্যা ও লাখ গ্রুপিং', () {
    expect(money(125000), '৳১,২৫০');
    expect(money(1250), '৳১২.৫০');
    expect(money(123456700), '৳১২,৩৪,৫৬৭');
    expect(money(-50000), '-৳৫০০');
    NumFmt.bengali = false;
    expect(money(125050), '৳1,250.50');
  });

  test('টাকা পার্স — বাংলা/ইংরেজি সংখ্যা', () {
    expect(parseMoney('১২.৫০'), 1250);
    expect(parseMoney('1,250'), 125000);
    expect(parseMoney(''), null);
    expect(parseMoney('abc'), null);
    expect(paisaToPlain(125050), '1250.5');
    expect(paisaToPlain(125000), '1250');
  });

  test('ক্যালকুলেটর', () {
    expect(evaluateExpression('120+45'), 16500);
    expect(evaluateExpression('১২০+৪৫'), 16500);
    expect(evaluateExpression('100−20×2'), 6000);
    expect(evaluateExpression('100÷4'), 2500);
    expect(evaluateExpression('10.5+'), 1050);
    expect(evaluateExpression('5÷0'), null);
    expect(evaluateExpression(''), null);
  });

  test('নাম্বার প্যাড', () {
    var e = '';
    for (final k in ['1', '2', '+', '+', '−', '3']) {
      e = applyKey(e, k);
    }
    expect(e, '12−3');
    expect(applyKey('1.25', '9'), '1.25');
    expect(applyKey('0', '5'), '5');
    expect(applyKey('', '.'), '0.');
    expect(applyKey('12', '⌫'), '1');
  });

  test('তারিখ', () {
    expect(monthLabel(DateTime(2026, 11)), 'নভেম্বর ২০২৬');
    expect(daysInMonth(DateTime(2026, 2)), 28);
    expect(DateRange.lastMonths(DateTime(2026, 2), 3).start, DateTime(2025, 12));
    expect(DateRange.month(DateTime(2026, 11)).months.length, 1);
  });
}
