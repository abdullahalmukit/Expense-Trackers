import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takar_khata/core/theme.dart';
import 'package:takar_khata/data/database.dart';
import 'package:takar_khata/data/repo.dart';
import 'package:takar_khata/domain/finance.dart';
import 'package:takar_khata/providers.dart';
import 'package:takar_khata/ui/debt/person_screen.dart';
import 'package:takar_khata/ui/manage/budgets_screen.dart';
import 'package:takar_khata/ui/manage/categories_screen.dart';
import 'package:takar_khata/ui/manage/goals_screen.dart';
import 'package:takar_khata/ui/manage/persons_screen.dart';
import 'package:takar_khata/ui/manage/recurring_screen.dart';
import 'package:takar_khata/ui/manage/tags_screen.dart';
import 'package:takar_khata/ui/manage/wallets_screen.dart';
import 'package:takar_khata/ui/settings/data_screens.dart';
import 'package:takar_khata/ui/settings/settings_screen.dart';
import 'package:takar_khata/ui/shell.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<int> seed(AppDb db) async {
  final repo = Repo(db);
  await repo.seedIfNeeded();
  final cats = await db.select(db.categories).get();
  int cat(String n, int k) => cats.firstWhere((c) => c.name == n && c.kind == k).id;
  final now = DateTime.now();
  final rafi = await repo.findOrCreatePerson('রাফি');
  final sakib = await repo.findOrCreatePerson('সাকিব');
  await repo.addWallet('bKash', '📲', 50000);
  for (var m = 0; m < 4; m++) {
    final base = DateTime(now.year, now.month - m, 1);
    await repo.saveTxn(type: 1, amount: 800000, categoryId: cat('টিউশন', 1), occurredAt: base.add(const Duration(hours: 10)));
    for (var d = 0; d < 20; d += 3) {
      final at = base.add(Duration(days: d, hours: 13 + d % 7));
      if (at.isAfter(now)) continue;
      await repo.saveTxn(type: 0, amount: 12000 + d * 1500, categoryId: cat('খাবার', 0), occurredAt: at, note: d == 3 ? 'ট্যুরের খাবার #ট্যুর' : '');
      await repo.saveTxn(type: 0, amount: 4000 + d * 300, categoryId: cat('যাতায়াত', 0), occurredAt: at.add(const Duration(hours: 2)));
    }
  }
  final debtIn = await repo.ensureDebtCategory(1);
  final debtOut = await repo.ensureDebtCategory(0);
  await repo.saveTxn(type: 1, amount: 100000, categoryId: debtIn, debtAction: DebtAction.borrow, personId: rafi, occurredAt: now.subtract(const Duration(days: 9)), dueDate: now.add(const Duration(days: 2)));
  await repo.saveTxn(type: 0, amount: 50000, categoryId: debtOut, debtAction: DebtAction.repay, personId: rafi, occurredAt: now.subtract(const Duration(days: 4)));
  await repo.saveTxn(type: 0, amount: 20000, categoryId: debtOut, debtAction: DebtAction.lend, personId: sakib, occurredAt: now.subtract(const Duration(days: 7)));
  await repo.setBudget(now, 0, 1000000);
  await repo.setBudget(now, cat('খাবার', 0), 300000);
  await repo.addGoal('ল্যাপটপ', '💻', 0xFF00897B, 6000000, null);
  return rafi;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('সব স্ক্রিন ডাটা সহ খোলে (ফোনের মাপে, লাইট ও ডার্ক)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final db = AppDb(NativeDatabase.memory());
    final rafi = (await tester.runAsync(() => seed(db)))!;

    for (final brightness in [Brightness.light, Brightness.dark]) {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(brightness),
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            navigatorKey: nav,
            theme: buildTheme(brightness),
            locale: const Locale('bn', 'BD'),
            supportedLocales: const [Locale('bn', 'BD'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const Shell(),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('মাস শেষের ব্যালেন্স'), findsOneWidget);

      // স্ক্রল করে হোমের সব কার্ড
      await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
      await settle(tester);

      for (final tab in ['হিস্টোরি', 'পরিসংখ্যান', 'ধার', 'হোম']) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
      }
      await tester.tap(find.text('পরিসংখ্যান').last);
      await settle(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await settle(tester);
      await tester.tap(find.text('ওভারভিউ'));
      await settle(tester);
      await tester.tap(find.text('হিস্টোরি').last);
      await settle(tester);
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await settle(tester);

      for (final screen in <Widget>[
        const SettingsScreen(),
        const CategoriesScreen(),
        const PersonsScreen(),
        const WalletsScreen(),
        const BudgetsScreen(),
        const GoalsScreen(),
        const RecurringScreen(),
        const TagsScreen(),
        const ExportScreen(),
        PersonScreen(personId: rafi),
      ]) {
        nav.currentState!.push(MaterialPageRoute(builder: (_) => screen));
        await settle(tester);
        nav.currentState!.pop();
        await settle(tester);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
