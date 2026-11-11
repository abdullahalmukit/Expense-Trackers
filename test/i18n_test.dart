import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takar_khata/core/dates.dart';
import 'package:takar_khata/core/i18n.dart';
import 'package:takar_khata/core/money.dart';
import 'package:takar_khata/data/database.dart';
import 'package:takar_khata/data/repo.dart';
import 'package:takar_khata/domain/finance.dart';
import 'package:takar_khata/services/exporter.dart';
import 'package:takar_khata/services/importer.dart';

void english(bool on) {
  Lang.en = on;
  NumFmt.bengali = !on;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  tearDown(() => english(false));

  test('ইংরেজিতে তারিখ, সময়, টাকা', () {
    english(true);
    expect(tr('খরচ', 'Expense'), 'Expense');
    expect(monthLabel(DateTime(2026, 11)), 'November 2026');
    expect(monthShortLabel(DateTime(2026, 11)), 'Nov 26');
    expect(timeLabel(DateTime(2026, 11, 1, 21, 5)), '9:05 PM');
    expect(timeLabel(DateTime(2026, 11, 1, 0, 30)), '12:30 AM');
    expect(money(123456700), '৳12,34,567');
    expect(moneyCompact(150000), '1.5K');
    expect(DebtAction.label(DebtAction.repay), 'Repaid');
    english(false);
    expect(monthLabel(DateTime(2026, 11)), 'নভেম্বর ২০২৬');
    expect(timeLabel(DateTime(2026, 11, 1, 21, 5)), 'রাত ৯:০৫');
  });

  test('ধারের লেবেল দুই ভাষাতেই চেনা যায়', () {
    for (var a = 0; a < 4; a++) {
      expect(DebtAction.parse(DebtAction.bnLabels[a]), a);
      expect(DebtAction.parse(DebtAction.enLabels[a]), a);
      expect(DebtAction.parse(DebtAction.enFull[a].toUpperCase()), a);
    }
  });

  test('ভাষা বদলালে না-বদলানো ডিফল্ট নামও বদলায়, নিজের দেওয়া নাম থাকে', () async {
    final db = AppDb(NativeDatabase.memory());
    final repo = Repo(db);
    await repo.setLanguage('bn');
    final food = (await db.select(db.categories).get()).firstWhere((c) => c.name == 'খাবার');
    await repo.addCategory(name: 'চা-নাস্তা', emoji: '☕', color: 0, kind: 0);
    await repo.setLanguage('en');
    final names = (await db.select(db.categories).get()).map((c) => c.name).toSet();
    expect(names, containsAll(['Food', 'Transport', 'Debt', 'Tuition', 'চা-নাস্তা']));
    expect(names.contains('খাবার'), false);
    expect((await db.select(db.wallets).get()).single.name, 'Cash');
    expect(await repo.getSetting('lang'), 'en');
    // ID একই থাকে, শুধু নাম বদলায়
    expect((await db.select(db.categories).get()).firstWhere((c) => c.id == food.id).name, 'Food');
    await repo.setLanguage('bn');
    expect((await db.select(db.wallets).get()).single.name, 'ক্যাশ');
    await db.close();
  });

  test('প্রথমবার ইংরেজি বাছলে ইংরেজি ডিফল্ট ক্যাটাগরি', () async {
    final db = AppDb(NativeDatabase.memory());
    await Repo(db).setLanguage('en');
    final cats = await db.select(db.categories).get();
    expect(cats.any((c) => c.name == 'Groceries'), true);
    expect(cats.any((c) => c.name == 'বাজার'), false);
    await db.close();
  });

  test('ইংরেজি CSV → বাংলা অ্যাপে ইমপোর্ট', () async {
    final db = AppDb(NativeDatabase.memory());
    final repo = Repo(db);
    await repo.setLanguage('en');
    final cats = await db.select(db.categories).get();
    final debtIn = cats.firstWhere((c) => c.isDebt && c.kind == 1);
    final p = await repo.findOrCreatePerson('Rafi');
    await repo.saveTxn(
      type: 0,
      amount: 5000,
      categoryId: cats.first.id,
      occurredAt: DateTime(2026, 11, 2),
      note: 'tea',
    );
    await repo.saveTxn(
      type: 1,
      amount: 100000,
      categoryId: debtIn.id,
      debtAction: DebtAction.borrow,
      personId: p,
      occurredAt: DateTime(2026, 11, 3),
    );
    english(true);
    final fin = FinanceData(
      txns: await db.select(db.transactions).get(),
      cats: cats,
      persons: await db.select(db.persons).get(),
      wallets: await db.select(db.wallets).get(),
      transfers: const [],
      budgets: const [],
    );
    final csv = Exporter.csvBytes(fin, null);
    expect(utf8.decode(csv.sublist(3)).startsWith('ID,Date,Type,Amount'), true);
    final xlsx = Exporter.xlsxBytes(fin, null);
    english(false);

    final db2 = AppDb(NativeDatabase.memory());
    final repo2 = Repo(db2);
    await repo2.setLanguage('bn');
    expect(await Importer.merge(repo2, Importer.parse('a.csv', csv)), 2);
    expect(Importer.parse('a.xlsx', xlsx).rows.length, 2);
    final txns = await db2.select(db2.transactions).get();
    final borrow = txns.firstWhere((t) => t.debtAction != null);
    expect(borrow.debtAction, DebtAction.borrow);
    expect(borrow.type, TxType.income);
    expect(txns.firstWhere((t) => t.debtAction == null).type, TxType.expense);
    await db.close();
    await db2.close();
  });
}
