import 'dart:convert';
import 'dart:typed_data';

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:takar_khata/core/dates.dart';
import 'package:takar_khata/data/database.dart';
import 'package:takar_khata/data/repo.dart';
import 'package:takar_khata/domain/finance.dart';
import 'package:takar_khata/services/backup.dart';
import 'package:takar_khata/services/exporter.dart';
import 'package:takar_khata/services/importer.dart';

Future<FinanceData> load(AppDb db) async => FinanceData(
  txns: await db.select(db.transactions).get(),
  cats: await db.select(db.categories).get(),
  persons: await db.select(db.persons).get(),
  wallets: await db.select(db.wallets).get(),
  transfers: await db.select(db.transfers).get(),
  budgets: await db.select(db.budgets).get(),
);

class FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final dir = Directory.systemTemp.createTempSync('takar');
  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
  @override
  Future<String?> getTemporaryPath() async => dir.path;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final paths = FakePaths();
  PathProviderPlatform.instance = paths;
  late AppDb db;
  late Repo repo;

  setUp(() async {
    db = AppDb(NativeDatabase.memory());
    repo = Repo(db);
    await repo.seedIfNeeded();
  });
  tearDown(() => db.close());

  Future<void> seedData() async {
    final cats = await db.select(db.categories).get();
    final food = cats.firstWhere((c) => c.name == 'খাবার');
    final debtIn = cats.firstWhere((c) => c.isDebt && c.kind == 1);
    final rafi = await repo.findOrCreatePerson('রাফি');
    await repo.saveTxn(
      type: 0,
      amount: 12050,
      categoryId: food.id,
      occurredAt: DateTime(2026, 11, 2, 13, 5),
      note: 'দুপুরের খাবার, "ক্যান্টিন" #ক্যাম্পাস',
    );
    await repo.saveTxn(
      type: 1,
      amount: 100000,
      categoryId: debtIn.id,
      debtAction: DebtAction.borrow,
      personId: rafi,
      occurredAt: DateTime(2026, 11, 1),
      dueDate: DateTime(2026, 12, 1),
    );
    await repo.setBudget(DateTime(2026, 11), 0, 500000);
  }

  test('ডিফল্ট ক্যাটাগরি ও ওয়ালেট তৈরি হয়', () async {
    final cats = await db.select(db.categories).get();
    expect(cats.where((c) => c.isDebt).length, 2);
    expect(cats.any((c) => c.name == 'টিউশন' && c.kind == 1), true);
    expect((await db.select(db.wallets).get()).single.name, 'ক্যাশ');
  });

  test('JSON ব্যাকআপ হুবহু ফেরত আসে', () async {
    await seedData();
    final bytes = await Backup.bytes(db);
    final before = await db.select(db.transactions).get();

    final db2 = AppDb(NativeDatabase.memory());
    final repo2 = Repo(db2);
    await repo2.seedIfNeeded();
    final bundle = Importer.parse('backup.json', bytes);
    expect(bundle.isFullBackup, true);
    final n = await Importer.replace(repo2, bundle);
    expect(n, 2);
    final after = await db2.select(db2.transactions).get();
    expect(after.map((t) => t.toJson()).toSet().length, before.length);
    for (final t in before) {
      expect(after.firstWhere((x) => x.id == t.id), t);
    }
    expect((await db2.select(db2.budgets).get()).single.limitAmount, 500000);
    // বদলানোর আগে সুরক্ষা-ব্যাকআপ রাখা হয়েছে
    final safety = await Backup.listBackups(prefix: 'takar-khata-safety');
    expect(safety, isNotEmpty);
    await db2.close();
  });

  test('JSON মিলিয়ে যোগ — ডুপ্লিকেট বাদ', () async {
    await seedData();
    final bytes = await Backup.bytes(db);
    final bundle = Importer.parse('backup.json', bytes);
    final p = await Importer.preview(repo, bundle);
    expect(p.duplicates, 2);
    expect(await Importer.merge(repo, bundle), 0);

    final db2 = AppDb(NativeDatabase.memory());
    final repo2 = Repo(db2);
    await repo2.seedIfNeeded();
    expect(await Importer.merge(repo2, bundle), 2);
    final fin2 = await load(db2);
    expect(fin2.debts().single.person.name, 'রাফি');
    expect(fin2.debts().single.payable, 100000);
    await db2.close();
  });

  test('CSV এক্সপোর্ট → ইমপোর্ট', () async {
    await seedData();
    final fin = await load(db);
    final csv = Exporter.csvBytes(fin, DateRange.month(DateTime(2026, 11)));
    final text = utf8.decode(csv.sublist(3));
    expect(text.split('\r\n').first.startsWith('ID,তারিখ'), true);

    final db2 = AppDb(NativeDatabase.memory());
    final repo2 = Repo(db2);
    await repo2.seedIfNeeded();
    final bundle = Importer.parse('x.csv', csv);
    expect(bundle.rows.length, 2);
    expect(await Importer.merge(repo2, bundle), 2);
    expect(await Importer.merge(repo2, bundle), 0); // আবার ইমপোর্টে ডুপ্লিকেট নয়
    final fin2 = await load(db2);
    final lunch = fin2.txns.firstWhere((t) => t.type == 0);
    expect(lunch.amount, 12050);
    expect(lunch.note, 'দুপুরের খাবার, "ক্যান্টিন" #ক্যাম্পাস');
    expect(fin2.catById[lunch.categoryId]!.name, 'খাবার');
    expect(fin2.debts().single.payable, 100000);
    await db2.close();
  });

  test('নিজে বানানো CSV — ID ছাড়া, অজানা ক্যাটাগরি নিজে তৈরি', () async {
    const text =
        'date,type,amount,category,note\n05/11/2026,খরচ,২৫০,চা-নাস্তা,বন্ধুদের সাথে\n2026-11-06,income,1500,টিউশন,\n';
    final b = Importer.parse('mine.csv', Uint8List.fromList(utf8.encode(text)));
    expect(b.rows.length, 2);
    final p = await Importer.preview(repo, b);
    expect(p.newCategories, {'চা-নাস্তা'});
    expect(await Importer.merge(repo, b), 2);
    expect(
      await Importer.merge(repo, Importer.parse('mine.csv', Uint8List.fromList(utf8.encode(text)))),
      0,
    );
    final fin = await load(db);
    expect(fin.cats.any((c) => c.name == 'চা-নাস্তা' && c.kind == 0), true);
    expect(fin.txns.firstWhere((t) => t.type == 0).amount, 25000);
  });

  test('Excel এক্সপোর্ট → ইমপোর্ট', () async {
    await seedData();
    final fin = await load(db);
    final x = Exporter.xlsxBytes(fin, null);
    final b = Importer.parse('a.xlsx', x);
    expect(b.rows.length, 2);
    expect(b.rows.map((r) => r.txn.amount).toSet(), {12050, 100000});
  });

  test('Word রিপোর্ট তৈরি হয়', () async {
    await seedData();
    final d = Exporter.docxBytes(await load(db), null);
    expect(d.length, greaterThan(500));
    expect(String.fromCharCodes(d.sublist(0, 2)), 'PK');
  });

  test('ক্যাটাগরি ডিলিট — এন্ট্রি অন্যটিতে সরানো', () async {
    await seedData();
    final cats = await db.select(db.categories).get();
    final food = cats.firstWhere((c) => c.name == 'খাবার');
    final bazar = cats.firstWhere((c) => c.name == 'বাজার');
    expect(await repo.countTxnsInCategory(food.id), 1);
    await repo.deleteCategory(food.id, moveTo: bazar.id);
    expect(await repo.countTxnsInCategory(bazar.id), 1);
  });

  test('রিকারিং এন্ট্রি নিজে যোগ হয়', () async {
    final cats = await db.select(db.categories).get();
    final food = cats.firstWhere((c) => c.name == 'খাবার');
    await repo.saveRecurring(
      RecurringsCompanion.insert(
        title: 'মেস ভাড়া',
        type: 0,
        amount: 300000,
        categoryId: food.id,
        dayOfMonth: 5,
        nextDate: DateTime(2026, 9, 5, 9),
      ),
    );
    await repo.processRecurring(now: DateTime(2026, 11, 11));
    final txns = await db.select(db.transactions).get();
    expect(txns.length, 3); // সেপ্টে, অক্টো, নভে
    final r = (await db.select(db.recurrings).get()).single;
    expect(r.nextDate, DateTime(2026, 12, 5, 9));
  });
}
