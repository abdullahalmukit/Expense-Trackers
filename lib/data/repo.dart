import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../domain/finance.dart';
import 'database.dart';
import 'defaults.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// ডাটাবেসের সব লেখা-পড়া এক জায়গায়।
class Repo {
  final AppDb db;
  Repo(this.db);

  // ---------------- streams ----------------

  Stream<List<Cat>> watchCategories() =>
      (db.select(db.categories)..orderBy([
            (c) => OrderingTerm.asc(c.kind),
            (c) => OrderingTerm.asc(c.sortOrder),
            (c) => OrderingTerm.asc(c.id),
          ]))
          .watch();

  Stream<List<Txn>> watchTxns() =>
      (db.select(db.transactions)..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])).watch();

  Stream<List<Person>> watchPersons() =>
      (db.select(db.persons)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();

  Stream<List<Wallet>> watchWallets() => (db.select(
    db.wallets,
  )..orderBy([(w) => OrderingTerm.asc(w.sortOrder), (w) => OrderingTerm.asc(w.id)])).watch();

  Stream<List<Transfer>> watchTransfers() =>
      (db.select(db.transfers)..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])).watch();

  Stream<List<Budget>> watchBudgets() => db.select(db.budgets).watch();
  Stream<List<Goal>> watchGoals() => db.select(db.goals).watch();
  Stream<List<Recurring>> watchRecurrings() => db.select(db.recurrings).watch();

  Stream<Map<String, String>> watchSettings() =>
      db.select(db.settings).watch().map((rows) => {for (final r in rows) r.key: r.value});

  // ---------------- seed ----------------

  Future<void> seedIfNeeded({bool en = false}) async {
    final seeded = await getSetting('seeded');
    if (seeded == '1') return;
    await db.transaction(() async {
      final cats = await db.select(db.categories).get();
      if (cats.isEmpty) {
        await db.batch((b) => b.insertAll(db.categories, defaultCategories(en: en)));
      }
      final ws = await db.select(db.wallets).get();
      if (ws.isEmpty) {
        await db.batch((b) => b.insertAll(db.wallets, defaultWallets(en: en)));
      }
      await setSetting('seeded', '1');
    });
  }

  /// প্রতিটি ধরনের জন্য সিস্টেমের 'ধার' ক্যাটাগরি থাকা নিশ্চিত করে।
  Future<int> ensureDebtCategory(int kind) async {
    final existing = await (db.select(
      db.categories,
    )..where((c) => c.isDebt.equals(true) & c.kind.equals(kind))).get();
    if (existing.isNotEmpty) {
      final c = existing.first;
      if (c.archived) {
        await (db.update(db.categories)..where((x) => x.id.equals(c.id))).write(
          const CategoriesCompanion(archived: Value(false)),
        );
      }
      return c.id;
    }
    return db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: tr('ধার', 'Debt'),
            emoji: '🤝',
            color: 0xFF7E57C2,
            kind: kind,
            sortOrder: const Value(99),
            isDebt: const Value(true),
          ),
        );
  }

  /// ভাষা বদলানো: সেটিং সেভ, আর যেসব ডিফল্ট ক্যাটাগরি/ওয়ালেটের নাম
  /// ব্যবহারকারী বদলাননি সেগুলো নতুন ভাষায় বদলানো।
  Future<void> setLanguage(String code) async {
    final en = code == 'en';
    await db.transaction(() async {
      await setSetting('lang', code);
      // সংখ্যার ধরন ভাষার সাথে মিলিয়ে (পরে সেটিংসে আলাদা করে বদলানো যায়)
      await removeSetting('digits');
      String? swap(String name) {
        for (final (bn, enName) in defaultNamePairs) {
          if (en && name == bn) return enName;
          if (!en && name == enName) return bn;
        }
        return null;
      }

      for (final c in await db.select(db.categories).get()) {
        final n = swap(c.name);
        if (n != null) await updateCategory(c.copyWith(name: n));
      }
      for (final w in await db.select(db.wallets).get()) {
        final n = swap(w.name);
        if (n != null) await updateWallet(w.copyWith(name: n));
      }
    });
    await seedIfNeeded(en: en);
  }

  // ---------------- settings ----------------

  Future<String?> getSetting(String key) async {
    final r = await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return r?.value;
  }

  Future<void> setSetting(String key, String value) =>
      db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> removeSetting(String key) =>
      (db.delete(db.settings)..where((s) => s.key.equals(key))).go();

  // ---------------- transactions ----------------

  Future<Txn> saveTxn({
    String? id,
    required int type,
    required int amount,
    required int categoryId,
    int? debtAction,
    int? personId,
    int? walletId,
    required DateTime occurredAt,
    String note = '',
    String purpose = '',
    String? photoPath,
    DateTime? dueDate,
  }) async {
    final now = DateTime.now();
    final existing = id == null
        ? null
        : await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    final row = Txn(
      id: id ?? newId(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      debtAction: debtAction,
      personId: debtAction == null ? null : personId,
      walletId: walletId,
      occurredAt: occurredAt,
      note: note.trim(),
      purpose: purpose.trim(),
      photoPath: photoPath,
      dueDate: debtAction == null ? null : dueDate,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await db.into(db.transactions).insertOnConflictUpdate(row);
    return row;
  }

  Future<void> insertTxn(Txn t) => db.into(db.transactions).insertOnConflictUpdate(t);

  Future<void> deleteTxn(String id) =>
      (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();

  Future<Txn?> getTxn(String id) =>
      (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Txn>> allTxns() => db.select(db.transactions).get();

  // ---------------- categories ----------------

  Future<int> addCategory({
    required String name,
    required String emoji,
    required int color,
    required int kind,
  }) async {
    final maxOrder =
        await (db.selectOnly(db.categories)
              ..addColumns([db.categories.sortOrder.max()])
              ..where(db.categories.kind.equals(kind) & db.categories.isDebt.equals(false)))
            .map((r) => r.read(db.categories.sortOrder.max()))
            .getSingleOrNull();
    return db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name.trim(),
            emoji: emoji,
            color: color,
            kind: kind,
            sortOrder: Value((maxOrder ?? -1) + 1),
          ),
        );
  }

  Future<void> updateCategory(Cat c) => db.update(db.categories).replace(c);

  Future<void> reorderCategories(List<Cat> ordered) => db.batch((b) {
    for (var i = 0; i < ordered.length; i++) {
      b.update(
        db.categories,
        CategoriesCompanion(sortOrder: Value(i)),
        where: (c) => c.id.equals(ordered[i].id),
      );
    }
  });

  Future<int> countTxnsInCategory(int id) async {
    final c = db.transactions.id.count();
    return (await (db.selectOnly(db.transactions)
              ..addColumns([c])
              ..where(db.transactions.categoryId.equals(id)))
            .map((r) => r.read(c))
            .getSingle()) ??
        0;
  }

  /// এন্ট্রি অন্য ক্যাটাগরিতে সরিয়ে তারপর মুছে ফেলা
  Future<void> deleteCategory(int id, {int? moveTo}) async {
    await db.transaction(() async {
      if (moveTo != null) {
        final target = await (db.select(
          db.categories,
        )..where((c) => c.id.equals(moveTo))).getSingle();
        await (db.update(db.transactions)..where((t) => t.categoryId.equals(id))).write(
          TransactionsCompanion(categoryId: Value(moveTo), type: Value(target.kind)),
        );
        // সাধারণ ক্যাটাগরিতে সরালে ধারের তথ্য বাদ
        if (!target.isDebt) {
          await (db.update(db.transactions)..where((t) => t.categoryId.equals(moveTo))).write(
            const TransactionsCompanion(debtAction: Value(null), personId: Value(null)),
          );
        }
      }
      await (db.delete(db.budgets)..where((b) => b.categoryId.equals(id))).go();
      await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
    });
  }

  Future<void> setCategoryArchived(int id, bool archived) => (db.update(
    db.categories,
  )..where((c) => c.id.equals(id))).write(CategoriesCompanion(archived: Value(archived)));

  // ---------------- persons ----------------

  Future<int> findOrCreatePerson(String name) async {
    final n = name.trim();
    final existing = await (db.select(
      db.persons,
    )..where((p) => p.name.lower().equals(n.toLowerCase()))).get();
    if (existing.isNotEmpty) return existing.first.id;
    return db.into(db.persons).insert(PersonsCompanion.insert(name: n));
  }

  Future<void> updatePerson(Person p) => db.update(db.persons).replace(p);

  Future<int> countTxnsOfPerson(int id) async {
    final c = db.transactions.id.count();
    return (await (db.selectOnly(db.transactions)
              ..addColumns([c])
              ..where(db.transactions.personId.equals(id)))
            .map((r) => r.read(c))
            .getSingle()) ??
        0;
  }

  Future<void> deletePerson(int id) => (db.delete(db.persons)..where((p) => p.id.equals(id))).go();

  /// একই মানুষ দুই নামে থাকলে একত্র করা
  Future<void> mergePerson(int from, int into) async {
    await db.transaction(() async {
      await (db.update(
        db.transactions,
      )..where((t) => t.personId.equals(from))).write(TransactionsCompanion(personId: Value(into)));
      await deletePerson(from);
    });
  }

  // ---------------- wallets & transfers ----------------

  Future<int> addWallet(String name, String emoji, int opening) => db
      .into(db.wallets)
      .insert(
        WalletsCompanion.insert(name: name.trim(), emoji: emoji, openingBalance: Value(opening)),
      );

  Future<void> updateWallet(Wallet w) => db.update(db.wallets).replace(w);

  Future<int> countWalletUse(int id) async {
    final c = db.transactions.id.count();
    final n =
        await (db.selectOnly(db.transactions)
              ..addColumns([c])
              ..where(db.transactions.walletId.equals(id)))
            .map((r) => r.read(c))
            .getSingle();
    final tr = await (db.select(
      db.transfers,
    )..where((t) => t.fromWalletId.equals(id) | t.toWalletId.equals(id))).get();
    return (n ?? 0) + tr.length;
  }

  Future<void> deleteWallet(int id) => (db.delete(db.wallets)..where((w) => w.id.equals(id))).go();

  Future<void> saveTransfer({
    String? id,
    required int from,
    required int to,
    required int amount,
    required DateTime at,
    String note = '',
  }) => db
      .into(db.transfers)
      .insertOnConflictUpdate(
        Transfer(
          id: id ?? newId(),
          fromWalletId: from,
          toWalletId: to,
          amount: amount,
          occurredAt: at,
          note: note.trim(),
          createdAt: DateTime.now(),
        ),
      );

  Future<void> deleteTransfer(String id) =>
      (db.delete(db.transfers)..where((t) => t.id.equals(id))).go();

  // ---------------- budgets ----------------

  /// এই মাস থেকে প্রযোজ্য বাজেট সেট (০ = বাজেট বাদ)
  Future<void> setBudget(DateTime month, int categoryId, int limit) async {
    final key = monthKey(month);
    await db.transaction(() async {
      await (db.delete(
        db.budgets,
      )..where((b) => b.month.equals(key) & b.categoryId.equals(categoryId))).go();
      await db
          .into(db.budgets)
          .insert(BudgetsCompanion.insert(month: key, categoryId: categoryId, limitAmount: limit));
    });
  }

  // ---------------- goals ----------------

  Future<int> addGoal(String name, String emoji, int color, int target, DateTime? deadline) => db
      .into(db.goals)
      .insert(
        GoalsCompanion.insert(
          name: name.trim(),
          emoji: emoji,
          color: color,
          target: target,
          deadline: Value(deadline),
          createdAt: DateTime.now(),
        ),
      );

  Future<void> updateGoal(Goal g) => db.update(db.goals).replace(g);
  Future<void> deleteGoal(int id) => (db.delete(db.goals)..where((g) => g.id.equals(id))).go();

  // ---------------- recurring ----------------

  Future<void> saveRecurring(RecurringsCompanion c) =>
      db.into(db.recurrings).insertOnConflictUpdate(c);

  Future<void> deleteRecurring(int id) =>
      (db.delete(db.recurrings)..where((r) => r.id.equals(id))).go();

  /// সময় হয়ে যাওয়া রিকারিং এন্ট্রি যোগ করে; যেগুলো autoAdd নয় সেগুলো ফেরত দেয় (রিমাইন্ডারের জন্য)।
  Future<List<Recurring>> processRecurring({DateTime? now}) async {
    now ??= DateTime.now();
    final due = <Recurring>[];
    final list = await (db.select(db.recurrings)..where((r) => r.active.equals(true))).get();
    for (final r in list) {
      var next = r.nextDate;
      var guard = 0;
      while (!next.isAfter(now) && guard++ < 24) {
        if (r.autoAdd) {
          await saveTxn(
            type: r.type,
            amount: r.amount,
            categoryId: r.categoryId,
            walletId: r.walletId,
            occurredAt: next,
            note: r.note.isEmpty ? r.title : r.note,
            purpose: tr('রিকারিং', 'Recurring'),
          );
        } else {
          due.add(r);
        }
        next = nextOccurrence(next, r.dayOfMonth);
        if (!r.autoAdd) break;
      }
      if (r.autoAdd && next != r.nextDate) {
        await (db.update(
          db.recurrings,
        )..where((x) => x.id.equals(r.id))).write(RecurringsCompanion(nextDate: Value(next)));
      }
    }
    return due;
  }

  /// রিমাইন্ডার-টাইপ রিকারিং এন্ট্রি যোগ করা হলে পরের মাসে সরানো
  Future<void> advanceRecurring(Recurring r) =>
      (db.update(db.recurrings)..where((x) => x.id.equals(r.id))).write(
        RecurringsCompanion(nextDate: Value(nextOccurrence(r.nextDate, r.dayOfMonth))),
      );
}

/// পরের মাসের একই দিন (মাস ছোট হলে শেষ দিন), সকাল ৯টা
DateTime nextOccurrence(DateTime from, int day) {
  final m = DateTime(from.year, from.month + 1);
  final d = day.clamp(1, daysInMonth(m));
  return DateTime(m.year, m.month, d, 9);
}

/// এই মাসে বা পরের মাসে প্রথম ঘটনা
DateTime firstOccurrence(int day, {DateTime? now}) {
  now ??= DateTime.now();
  final d = day.clamp(1, daysInMonth(now));
  final candidate = DateTime(now.year, now.month, d, 9);
  if (!candidate.isBefore(dayStart(now))) return candidate;
  return nextOccurrence(candidate, day);
}

extension TxnX on Txn {
  bool get isDebt => debtAction != null;
  int get signedAmount => type == TxType.income ? amount : -amount;
}
