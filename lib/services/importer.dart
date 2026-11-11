import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:excel/excel.dart' as xl;
import 'package:uuid/uuid.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/repo.dart';
import '../domain/finance.dart';
import 'backup.dart';
import 'exporter.dart';

/// ইমপোর্টের একটি সারি — ক্যাটাগরি/ব্যক্তি/ওয়ালেট নামে, যাতে অন্য ফোনের ডাটাও মেলে
class ImportRow {
  final Txn txn;
  final String catName;
  final int catKind;
  final String? catEmoji;
  final int? catColor;
  final bool catIsDebt;
  final String? personName;
  final String? walletName;
  const ImportRow({
    required this.txn,
    required this.catName,
    required this.catKind,
    this.catEmoji,
    this.catColor,
    this.catIsDebt = false,
    this.personName,
    this.walletName,
  });
}

class ImportBundle {
  final String format; // json / csv / xlsx
  final List<ImportRow> rows;
  final List<Cat> cats;
  final List<Person> persons;
  final List<Wallet> wallets;
  final List<Transfer> transfers;
  final List<Budget> budgets;
  final List<Goal> goals;
  final List<Recurring> recurrings;
  final Map<String, String> settings;
  final List<String> warnings;

  ImportBundle({
    required this.format,
    required this.rows,
    this.cats = const [],
    this.persons = const [],
    this.wallets = const [],
    this.transfers = const [],
    this.budgets = const [],
    this.goals = const [],
    this.recurrings = const [],
    this.settings = const {},
    this.warnings = const [],
  });

  bool get isFullBackup => format == 'json';

  /// কোন কোন মাস (নতুন আগে) আর প্রতিটিতে কত এন্ট্রি
  Map<String, int> get monthCounts {
    final m = <String, int>{};
    for (final r in rows) {
      final k = monthKey(r.txn.occurredAt);
      m[k] = (m[k] ?? 0) + 1;
    }
    final keys = m.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: m[k]!};
  }
}

class ImportPreview {
  final int total;
  final int duplicates;
  final Set<String> newCategories;
  final Set<String> newPersons;
  const ImportPreview(this.total, this.duplicates, this.newCategories, this.newPersons);
}

class Importer {
  static const _uuid = Uuid();

  static ImportBundle parse(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.json')) return _json(bytes);
    if (lower.endsWith('.xlsx')) return _xlsx(bytes);
    if (lower.endsWith('.csv') || lower.endsWith('.txt')) return _csv(bytes);
    throw const FormatException('এই ফাইল সমর্থিত নয় — JSON, Excel (.xlsx) বা CSV বাছুন');
  }

  // ---------------- JSON ----------------

  static ImportBundle _json(Uint8List bytes) {
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map || data['format'] != Backup.format) {
      throw const FormatException('এটি টাকার খাতার ব্যাকআপ ফাইল নয়');
    }
    List<Map<String, dynamic>> list(String k) =>
        [for (final e in (data[k] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
    final cats = list('categories').map(Cat.fromJson).toList();
    final persons = list('persons').map(Person.fromJson).toList();
    final wallets = list('wallets').map(Wallet.fromJson).toList();
    final catById = {for (final c in cats) c.id: c};
    final personById = {for (final p in persons) p.id: p};
    final walletById = {for (final w in wallets) w.id: w};
    final rows = <ImportRow>[];
    for (final m in list('transactions')) {
      final t = Txn.fromJson(m);
      final c = catById[t.categoryId];
      rows.add(
        ImportRow(
          txn: t,
          catName: c?.name ?? (m['categoryName'] as String? ?? 'অন্যান্য'),
          catKind: c?.kind ?? (m['categoryKind'] as int? ?? t.type),
          catEmoji: c?.emoji,
          catColor: c?.color,
          catIsDebt: c?.isDebt ?? t.debtAction != null,
          personName: t.personId == null ? null : (personById[t.personId]?.name ?? m['personName'] as String?),
          walletName: t.walletId == null ? null : (walletById[t.walletId]?.name ?? m['walletName'] as String?),
        ),
      );
    }
    return ImportBundle(
      format: 'json',
      rows: rows,
      cats: cats,
      persons: persons,
      wallets: wallets,
      transfers: list('transfers').map(Transfer.fromJson).toList(),
      budgets: list('budgets').map(Budget.fromJson).toList(),
      goals: list('goals').map(Goal.fromJson).toList(),
      recurrings: list('recurrings').map(Recurring.fromJson).toList(),
      settings: {
        for (final e in (data['settings'] as Map? ?? const {}).entries) '${e.key}': '${e.value}',
      },
    );
  }

  // ---------------- CSV / Excel ----------------

  static ImportBundle _csv(Uint8List bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    final table = Csv().decode(text);
    return _table('csv', [for (final r in table) [for (final c in r) c?.toString() ?? '']]);
  }

  static ImportBundle _xlsx(Uint8List bytes) {
    final book = xl.Excel.decodeBytes(bytes);
    final name = book.tables.containsKey('এন্ট্রি') ? 'এন্ট্রি' : book.tables.keys.first;
    final sheet = book.tables[name]!;
    final table = <List<String>>[];
    for (final row in sheet.rows) {
      table.add([for (final c in row) _cellText(c?.value)]);
    }
    return _table('xlsx', table);
  }

  static String _cellText(xl.CellValue? v) => switch (v) {
    null => '',
    xl.TextCellValue() => v.value.text ?? v.value.toString(),
    xl.IntCellValue() => '${v.value}',
    xl.DoubleCellValue() => '${v.value}',
    xl.DateTimeCellValue() => isoDateTime(v.asDateTimeLocal()),
    xl.DateCellValue() => isoDate(v.asDateTimeLocal()),
    _ => v.toString(),
  };

  static DateTime? _parseDate(String s) {
    final t = toEnDigits(s.trim());
    if (t.isEmpty) return null;
    final iso = DateTime.tryParse(t.replaceFirst(' ', 'T'));
    if (iso != null) return iso;
    // dd/mm/yyyy [hh:mm]
    final m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})(?:\s+(\d{1,2}):(\d{2}))?').firstMatch(t);
    if (m != null) {
      var y = int.parse(m[3]!);
      if (y < 100) y += 2000;
      return DateTime(y, int.parse(m[2]!), int.parse(m[1]!), int.parse(m[4] ?? '12'), int.parse(m[5] ?? '0'));
    }
    // Excel serial date
    final serial = double.tryParse(t);
    if (serial != null && serial > 20000 && serial < 80000) {
      return DateTime(1899, 12, 30).add(Duration(milliseconds: (serial * 86400000).round()));
    }
    return null;
  }

  static int? _parseType(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return null;
    if (t == 'খরচ' || t == 'expense' || t == '0' || t == 'debit') return TxType.expense;
    if (t == 'জমা' || t == 'income' || t == '1' || t == 'credit' || t == 'আয়') return TxType.income;
    return null;
  }

  static ImportBundle _table(String format, List<List<String>> table) {
    if (table.isEmpty) throw const FormatException('ফাইলটি খালি');
    final cols = Cols.resolve(table.first);
    if (!cols.containsKey(Cols.amount) || !cols.containsKey(Cols.date)) {
      throw const FormatException('কলাম চেনা যায়নি — অন্তত "তারিখ" ও "টাকা" কলাম লাগবে');
    }
    String get(List<String> row, String col) {
      final i = cols[col];
      if (i == null || i >= row.length) return '';
      return row[i].trim();
    }

    final rows = <ImportRow>[];
    final warnings = <String>[];
    final now = DateTime.now();
    for (var i = 1; i < table.length; i++) {
      final r = table[i];
      if (r.every((c) => c.trim().isEmpty)) continue;
      final date = _parseDate(get(r, Cols.date));
      var amount = parseMoney(get(r, Cols.amount));
      if (date == null || amount == null || amount == 0) {
        warnings.add('সারি ${dg(i + 1)}: তারিখ বা টাকা বোঝা যায়নি — বাদ');
        continue;
      }
      var type = _parseType(get(r, Cols.type));
      if (amount < 0) {
        type ??= TxType.expense;
        amount = -amount;
      }
      final debt = get(r, Cols.debt).isEmpty ? null : DebtAction.parse(get(r, Cols.debt));
      if (debt != null) type = DebtAction.typeOf(debt);
      type ??= TxType.expense;
      final person = get(r, Cols.person);
      var catName = get(r, Cols.category);
      if (catName.isEmpty) catName = debt != null ? 'ধার' : 'অন্যান্য';
      final note = get(r, Cols.note);
      final purpose = get(r, Cols.purpose);
      var id = get(r, Cols.id);
      if (id.isEmpty) {
        // একই ফাইল দুবার ইমপোর্ট করলে যাতে ডুপ্লিকেট না হয়
        id = _uuid.v5(Namespace.url.value, 'takar-khata:${date.toIso8601String()}|$type|$amount|$catName|$note|$person');
      }
      rows.add(
        ImportRow(
          txn: Txn(
            id: id,
            type: type,
            amount: amount,
            categoryId: 0,
            debtAction: person.isEmpty ? null : debt,
            personId: null,
            walletId: null,
            occurredAt: date,
            note: note,
            purpose: purpose,
            photoPath: null,
            dueDate: _parseDate(get(r, Cols.due)),
            createdAt: now,
            updatedAt: now,
          ),
          catName: catName,
          catKind: type,
          catEmoji: get(r, Cols.emoji).isEmpty ? null : get(r, Cols.emoji),
          catIsDebt: debt != null && person.isNotEmpty,
          personName: person.isEmpty || debt == null ? null : person,
          walletName: get(r, Cols.wallet).isEmpty ? null : get(r, Cols.wallet),
        ),
      );
    }
    return ImportBundle(format: format, rows: rows, warnings: warnings);
  }

  // ---------------- প্রিভিউ ও প্রয়োগ ----------------

  static Future<ImportPreview> preview(Repo repo, ImportBundle b) async {
    final db = repo.db;
    final existing = {for (final t in await db.select(db.transactions).get()) t.id};
    final cats = await db.select(db.categories).get();
    final persons = await db.select(db.persons).get();
    final catKeys = {for (final c in cats) '${c.kind}|${c.isDebt ? '#debt' : c.name.toLowerCase()}'};
    final personKeys = {for (final p in persons) p.name.toLowerCase()};
    final newCats = <String>{};
    final newPersons = <String>{};
    var dup = 0;
    for (final r in b.rows) {
      if (existing.contains(r.txn.id)) dup++;
      final key = '${r.catKind}|${r.catIsDebt ? '#debt' : r.catName.toLowerCase()}';
      if (!catKeys.contains(key)) newCats.add(r.catName);
      if (r.personName != null && !personKeys.contains(r.personName!.toLowerCase())) {
        newPersons.add(r.personName!);
      }
    }
    return ImportPreview(b.rows.length, dup, newCats, newPersons);
  }

  /// 'মিলিয়ে যোগ করুন' — ইউনিক ID দেখে ডুপ্লিকেট বাদ। ফেরত দেয় কতগুলো যোগ হলো।
  static Future<int> merge(Repo repo, ImportBundle b) async {
    final db = repo.db;
    var added = 0;
    await db.transaction(() async {
      final existing = {for (final t in await db.select(db.transactions).get()) t.id};
      final cats = await db.select(db.categories).get();
      final catMap = <String, int>{
        for (final c in cats) '${c.kind}|${c.isDebt ? '#debt' : c.name.toLowerCase()}': c.id,
      };
      final wallets = await db.select(db.wallets).get();
      final walletMap = {for (final w in wallets) w.name.toLowerCase(): w.id};
      final defaultWallet = wallets.isEmpty ? null : wallets.first.id;
      final personCache = <String, int>{};
      var colorIdx = cats.length;

      Future<int> catId(ImportRow r) async {
        final key = '${r.catKind}|${r.catIsDebt ? '#debt' : r.catName.toLowerCase()}';
        final found = catMap[key];
        if (found != null) return found;
        final int id;
        if (r.catIsDebt) {
          id = await repo.ensureDebtCategory(r.catKind);
        } else {
          id = await repo.addCategory(
            name: r.catName,
            emoji: r.catEmoji ?? (r.catKind == TxType.expense ? '🏷️' : '💰'),
            color: r.catColor ?? AppColors.palette[colorIdx++ % AppColors.palette.length].toARGB32(),
            kind: r.catKind,
          );
        }
        catMap[key] = id;
        return id;
      }

      Future<int?> walletId(String? name) async {
        if (name == null || name.isEmpty) return defaultWallet;
        final k = name.toLowerCase();
        final found = walletMap[k];
        if (found != null) return found;
        final emoji = b.wallets.where((w) => w.name.toLowerCase() == k).firstOrNull?.emoji ?? '👛';
        final id = await repo.addWallet(name, emoji, 0);
        walletMap[k] = id;
        return id;
      }

      for (final r in b.rows) {
        if (existing.contains(r.txn.id)) continue;
        int? personId;
        if (r.personName != null && r.txn.debtAction != null) {
          personId = personCache[r.personName!.toLowerCase()] ??= await repo.findOrCreatePerson(r.personName!);
        }
        await db.into(db.transactions).insert(
          r.txn.copyWith(
            categoryId: await catId(r),
            personId: Value(personId),
            walletId: Value(await walletId(r.walletName)),
            debtAction: Value(personId == null ? null : r.txn.debtAction),
          ),
        );
        existing.add(r.txn.id);
        added++;
      }

      if (b.isFullBackup) {
        final existingTransfers = {for (final t in await db.select(db.transfers).get()) t.id};
        final srcWallets = {for (final w in b.wallets) w.id: w.name};
        for (final t in b.transfers) {
          if (existingTransfers.contains(t.id)) continue;
          final from = await walletId(srcWallets[t.fromWalletId]);
          final to = await walletId(srcWallets[t.toWalletId]);
          if (from == null || to == null || from == to) continue;
          await db.into(db.transfers).insert(t.copyWith(fromWalletId: from, toWalletId: to));
        }
        final goalNames = {for (final g in await db.select(db.goals).get()) g.name.toLowerCase()};
        for (final g in b.goals) {
          if (goalNames.contains(g.name.toLowerCase())) continue;
          await db.into(db.goals).insert(g.toCompanion(true).copyWith(id: const Value.absent()));
        }
      }
    });
    return added;
  }

  /// 'সব বদলে দিন' — আগে নিজে একটি সুরক্ষা-ব্যাকআপ রাখা হয়।
  static Future<int> replace(Repo repo, ImportBundle b) async {
    final db = repo.db;
    await Backup.writeToBackupFolder(db, prefix: 'safety', keep: 5);
    if (!b.isFullBackup) {
      // CSV/Excel: সব এন্ট্রি মুছে ফাইলের এন্ট্রি বসানো; ক্যাটাগরি-ওয়ালেট থাকে
      await db.transaction(() async {
        await db.delete(db.transactions).go();
        await db.delete(db.transfers).go();
      });
      return merge(repo, b);
    }
    await db.transaction(() async {
      await db.wipeAll();
      await db.batch((batch) {
        batch.insertAll(db.categories, b.cats);
        batch.insertAll(db.persons, b.persons);
        batch.insertAll(db.wallets, b.wallets);
        batch.insertAll(db.transfers, b.transfers);
        batch.insertAll(db.budgets, b.budgets);
        batch.insertAll(db.goals, b.goals);
        batch.insertAll(db.recurrings, b.recurrings);
        batch.insertAll(db.transactions, [for (final r in b.rows) r.txn]);
      });
      for (final e in b.settings.entries) {
        await repo.setSetting(e.key, e.value);
      }
      if ((await db.select(db.wallets).get()).isEmpty) {
        await repo.addWallet('ক্যাশ', '💵', 0);
      }
      await repo.ensureDebtCategory(TxType.expense);
      await repo.ensureDebtCategory(TxType.income);
    });
    return b.rows.length;
  }
}
