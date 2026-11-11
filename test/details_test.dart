import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takar_khata/data/database.dart';
import 'package:takar_khata/data/repo.dart';
import 'package:takar_khata/providers.dart';
import 'package:takar_khata/ui/entry/entry_sheet.dart';
import 'package:takar_khata/ui/history/history_screen.dart';
import 'package:takar_khata/ui/settings/profile_screen.dart';
import 'package:takar_khata/ui/settings/settings_screen.dart';

import 'screens_test.dart' show settle;

Future<AppDb> withOneEntry(WidgetTester tester) async {
  final db = AppDb(NativeDatabase.memory());
  await tester.runAsync(() async {
    final repo = Repo(db);
    await repo.setLanguage('bn');
    final cats = await db.select(db.categories).get();
    await repo.saveTxn(
      type: 0,
      amount: 25000,
      categoryId: cats.firstWhere((c) => c.name == 'খাবার').id,
      occurredAt: DateTime.now(),
      note: 'দুপুরের খাবার #ক্যাম্পাস',
      purpose: 'অফিস',
    );
  });
  return db;
}

Widget host(AppDb db, Widget child) => ProviderScope(
  overrides: [dbProvider.overrideWithValue(db)],
  child: MaterialApp(home: child),
);

Future<void> done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() {});

  testWidgets('হিস্টোরিতে ট্যাপ → পূর্ণ বিবরণ, সেখান থেকে ডিলিট', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final db = await withOneEntry(tester);
    await tester.pumpWidget(host(db, const HistoryScreen()));
    await settle(tester);

    // সোয়াইপে আর ডিলিট হয় না
    expect(find.byType(Dismissible), findsNothing);
    // সারিতে এডিট ও ডিলিট বাটন
    expect(find.byTooltip('এডিট'), findsOneWidget);
    expect(find.byTooltip('ডিলিট'), findsOneWidget);

    await tester.tap(find.text('খাবার'));
    await settle(tester);
    expect(find.text('দুপুরের খাবার #ক্যাম্পাস'), findsWidgets);
    expect(find.text('অফিস'), findsOneWidget);
    expect(find.text('#ক্যাম্পাস'), findsOneWidget);
    expect(find.text('-৳২৫০'), findsWidgets);

    // বিবরণ থেকে ডিলিট → নিশ্চিত করার ডায়ালগ → মুছুন
    await tester.tap(find.widgetWithText(OutlinedButton, 'ডিলিট'));
    await settle(tester);
    expect(find.text('এন্ট্রি মুছবেন?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'মুছুন'));
    await settle(tester);
    expect((await tester.runAsync(() => db.select(db.transactions).get()))!, isEmpty);
    expect(find.text('ফিরিয়ে আনুন'), findsOneWidget); // Undo
    await done(tester);
  });

  testWidgets('বিবরণ থেকে এডিট চাপলে এডিট শিট খোলে', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final db = await withOneEntry(tester);
    await tester.pumpWidget(host(db, const HistoryScreen()));
    await settle(tester);
    await tester.tap(find.text('খাবার'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'এডিট'));
    await settle(tester);
    expect(find.byType(EntrySheet), findsOneWidget);
    expect(find.text('আপডেট'), findsOneWidget);
    await done(tester);
  });

  testWidgets('সারির ডিলিট বাটন — বাতিল চাপলে কিছু মোছে না', (tester) async {
    final db = await withOneEntry(tester);
    await tester.pumpWidget(host(db, const HistoryScreen()));
    await settle(tester);
    await tester.tap(find.byTooltip('ডিলিট'));
    await settle(tester);
    await tester.tap(find.text('বাতিল'));
    await settle(tester);
    expect((await tester.runAsync(() => db.select(db.transactions).get()))!.length, 1);
    await done(tester);
  });

  testWidgets('প্রোফাইল সেভ হয় ও সেটিংসে দেখায়', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final db = AppDb(NativeDatabase.memory());
    await tester.runAsync(() => Repo(db).setLanguage('bn'));
    await tester.pumpWidget(host(db, const SettingsScreen()));
    await settle(tester);
    expect(find.text('প্রোফাইল যোগ করুন'), findsOneWidget);

    await tester.tap(find.text('প্রোফাইল যোগ করুন'));
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'নাম'), 'রাকিব');
    await tester.enterText(find.widgetWithText(TextField, 'মোবাইল নম্বর'), '01700000000');
    await tester.enterText(find.widgetWithText(TextField, 'ইমেইল'), 'rakib@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'সেভ'));
    await settle(tester);

    final repo = Repo(db);
    expect(await tester.runAsync(() => repo.getSetting(ProfileFields.name)), 'রাকিব');
    expect(find.text('রাকিব'), findsOneWidget);
    expect(find.text('01700000000 · rakib@example.com'), findsOneWidget);

    // নিচে ডেভেলপার কার্ড
    await tester.scrollUntilVisible(
      find.text('Md. Abdul Mukit'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(find.text('Md. Abdul Mukit'), findsOneWidget);
    expect(find.text('abdullahalmukit287@gmail.com'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    await done(tester);
  });
}
