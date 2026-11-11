import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takar_khata/core/dates.dart';
import 'package:takar_khata/data/database.dart';
import 'package:takar_khata/data/repo.dart';
import 'package:takar_khata/domain/finance.dart';
import 'package:takar_khata/providers.dart';
import 'package:takar_khata/services/report.dart';
import 'package:takar_khata/ui/debt/debt_screen.dart';
import 'package:takar_khata/ui/entry/entry_sheet.dart';
import 'package:takar_khata/ui/home/home_screen.dart';

Widget host(AppDb db, Widget child) => ProviderScope(
  overrides: [dbProvider.overrideWithValue(db)],
  child: MaterialApp(home: child),
);

/// drift স্ট্রিমগুলো আসল async-এ চলে — কয়েকবার অপেক্ষা করে ফ্রেম আঁকা
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('খালি অবস্থায় হোমে বন্ধুসুলভ বার্তা', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    await tester.runAsync(() => Repo(db).seedIfNeeded());
    await tester.pumpWidget(host(db, const HomeScreen()));
    await settle(tester);
    expect(find.text('প্রথম এন্ট্রি যোগ করুন'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('এন্ট্রি শিট — নাম্বার প্যাডে টাকা লিখে ক্যাটাগরি বেছে সেভ', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final db = AppDb(NativeDatabase.memory());
    await tester.runAsync(() => Repo(db).seedIfNeeded());
    await tester.pumpWidget(host(db, const Scaffold(body: EntrySheet())));
    await settle(tester);

    for (final k in ['১', '২', '০', '+', '৪', '৫']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    expect(find.text('= ৳১৬৫'), findsOneWidget);
    await tester.tap(find.text('খাবার'));
    await tester.pump();
    await tester.tap(find.text('সেভ ও আরেকটা'));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    final txns = await tester.runAsync(() => db.select(db.transactions).get());
    expect(txns!.single.amount, 16500);
    expect(txns.single.type, TxType.expense);
    expect(find.text('১টি এন্ট্রি সেভ হয়েছে'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('ধার পেজ — আমি দেব / আমি পাব', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    final repo = Repo(db);
    await tester.runAsync(() async {
      await repo.seedIfNeeded();
      final debtIn = await repo.ensureDebtCategory(1);
      final debtOut = await repo.ensureDebtCategory(0);
      final rafi = await repo.findOrCreatePerson('রাফি');
      final sakib = await repo.findOrCreatePerson('সাকিব');
      await repo.saveTxn(type: 1, amount: 100000, categoryId: debtIn, debtAction: DebtAction.borrow, personId: rafi, occurredAt: DateTime(2026, 11, 1));
      await repo.saveTxn(type: 0, amount: 70000, categoryId: debtOut, debtAction: DebtAction.repay, personId: rafi, occurredAt: DateTime(2026, 11, 5));
      await repo.saveTxn(type: 0, amount: 20000, categoryId: debtOut, debtAction: DebtAction.lend, personId: sakib, occurredAt: DateTime(2026, 11, 3));
    });
    await tester.pumpWidget(host(db, const DebtScreen()));
    await settle(tester);
    expect(find.text('আমি দেব'), findsWidgets);
    expect(find.text('৳৩০০'), findsWidgets);
    expect(find.text('৳২০০'), findsWidgets);
    expect(find.text('দেব ৳৩০০'), findsOneWidget);
    expect(find.text('পাব ৳২০০'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('PDF রিপোর্টের পাতা অফস্ক্রিনে আঁকা যায়', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    final repo = Repo(db);
    final fin = await tester.runAsync(() async {
      await repo.seedIfNeeded();
      final cats = await db.select(db.categories).get();
      await repo.saveTxn(type: 0, amount: 25000, categoryId: cats.first.id, occurredAt: DateTime(2026, 11, 2), note: 'বাজার');
      return FinanceData(
        txns: await db.select(db.transactions).get(),
        cats: cats,
        persons: const [],
        wallets: await db.select(db.wallets).get(),
        transfers: const [],
        budgets: const [],
      );
    });
    final ui.Image? img = await tester.runAsync(
      () => renderToImage(const Center(child: Text('টাকার খাতা')), PdfReport.pageSize, pixelRatio: 1),
    );
    expect(img!.width, 595);
    final pdf = await tester.runAsync(() => PdfReport.build(fin!, DateRange.month(DateTime(2026, 11))));
    expect(String.fromCharCodes(pdf!.sublist(0, 4)), '%PDF');
  });
}
