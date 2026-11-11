import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../core/dates.dart';
import '../data/database.dart';
import 'files.dart';

/// JSON পূর্ণ ব্যাকআপ — সব এন্ট্রি, ক্যাটাগরি (ইমোজি-রং সহ), ব্যক্তি, ওয়ালেট, বাজেট, সেটিংস।
/// ইমপোর্ট করলে হুবহু ফিরে আসে।
class Backup {
  static const format = 'takar_khata_backup';
  static const version = 1;

  /// যেসব সেটিং ব্যাকআপে যাবে না (নিরাপত্তা বা ডিভাইস-নির্দিষ্ট)
  static bool _skipSetting(String k) =>
      k.startsWith('lock_') || k.startsWith('alert_') || k == 'last_backup' || k == 'seeded';

  static Future<Map<String, dynamic>> build(AppDb db, {DateRange? range}) async {
    final cats = await db.select(db.categories).get();
    final persons = await db.select(db.persons).get();
    final wallets = await db.select(db.wallets).get();
    var txns = await db.select(db.transactions).get();
    var transfers = await db.select(db.transfers).get();
    if (range != null) {
      txns = txns.where((t) => range.contains(t.occurredAt)).toList();
      transfers = transfers.where((t) => range.contains(t.occurredAt)).toList();
    }
    txns.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final catById = {for (final c in cats) c.id: c};
    final personById = {for (final x in persons) x.id: x};
    final walletById = {for (final w in wallets) w.id: w};
    final settings = await db.select(db.settings).get();
    return {
      'format': format,
      'version': version,
      'app': 'টাকার খাতা',
      'exportedAt': DateTime.now().toIso8601String(),
      if (range != null)
        'range': {'start': range.start.toIso8601String(), 'end': range.end.toIso8601String()},
      'categories': [for (final c in cats) c.toJson()],
      'persons': [for (final x in persons) x.toJson()],
      'wallets': [for (final w in wallets) w.toJson()],
      'transfers': [for (final t in transfers) t.toJson()],
      'budgets': [for (final b in await db.select(db.budgets).get()) b.toJson()],
      'goals': [for (final g in await db.select(db.goals).get()) g.toJson()],
      'recurrings': [for (final r in await db.select(db.recurrings).get()) r.toJson()],
      'settings': {for (final s in settings) if (!_skipSetting(s.key)) s.key: s.value},
      'transactions': [
        for (final t in txns)
          {
            ...t.toJson(),
            // পড়ার সুবিধা ও অন্য ডিভাইসে মেলানোর জন্য নামও রাখা হলো
            'categoryName': catById[t.categoryId]?.name,
            'categoryKind': catById[t.categoryId]?.kind,
            'personName': t.personId == null ? null : personById[t.personId]?.name,
            'walletName': t.walletId == null ? null : walletById[t.walletId]?.name,
          },
      ],
    };
  }

  static Future<Uint8List> bytes(AppDb db, {DateRange? range}) async {
    final map = await build(db, range: range);
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(map)));
  }

  static String fileName([String prefix = 'takar-khata-backup']) {
    final n = DateTime.now();
    final hm = '${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}';
    return '$prefix-${isoDate(n)}-$hm.json';
  }

  /// ফোনের Download/TakarKhata/backups ফোল্ডারে JSON ব্যাকআপ; শেষ [keep]টি রাখা হয়।
  static Future<File> writeToBackupFolder(AppDb db, {String prefix = 'auto', int keep = 10}) async {
    final dir = await Files.publicDir('backups');
    final f = File(p.join(dir.path, fileName('takar-khata-$prefix')));
    await f.writeAsBytes(await bytes(db), flush: true);
    await prune(dir, prefix: 'takar-khata-$prefix', keep: keep);
    return f;
  }

  static Future<void> prune(Directory dir, {required String prefix, int keep = 10}) async {
    final files = await listBackups(dir: dir, prefix: prefix);
    for (final f in files.skip(keep)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  /// নতুনটা আগে
  static Future<List<File>> listBackups({Directory? dir, String prefix = 'takar-khata'}) async {
    dir ??= await Files.publicDir('backups');
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((e) => e is File && p.basename(e.path).startsWith(prefix) && e.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// সেটিং অনুযায়ী অটো ব্যাকআপ দরকার কিনা — সাপ্তাহিক বা মাস শেষে
  static bool isDue(String mode, DateTime? last, {DateTime? now}) {
    now ??= DateTime.now();
    if (mode == 'off') return false;
    if (last == null) return true;
    if (mode == 'monthly') return !sameMonth(last, now);
    return now.difference(last).inDays >= 7;
  }
}
