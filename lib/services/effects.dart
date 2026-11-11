import 'dart:math' as math;

import '../core/dates.dart';
import '../core/money.dart';
import '../data/database.dart';
import '../data/repo.dart';
import '../domain/finance.dart';
import 'home_widget_service.dart';
import 'notifications.dart';

/// এন্ট্রি সেভ/ডিলিটের পরের কাজ: বাজেট সতর্কতা, ধারের রিমাইন্ডার, উইজেট আপডেট।
class Effects {
  Effects(this.repo);
  final Repo repo;

  Future<FinanceData> _fresh() async {
    final db = repo.db;
    return FinanceData(
      txns: await db.select(db.transactions).get(),
      cats: await db.select(db.categories).get(),
      persons: await db.select(db.persons).get(),
      wallets: await db.select(db.wallets).get(),
      transfers: await db.select(db.transfers).get(),
      budgets: await db.select(db.budgets).get(),
    );
  }

  Future<void> afterSave(Txn t) async {
    final fin = await _fresh();
    final settings = await _settings();
    if (t.type == TxType.expense && settings['budget_alerts'] != '0') {
      await _checkBudget(fin, t);
    }
    if (settings['debt_reminders'] != '0') await _scheduleDebt(fin, t);
    await refreshWidget(fin);
  }

  Future<void> afterDelete(String txnId) async {
    await Notify.instance.cancelDebt(txnId);
    await refreshWidget(await _fresh());
  }

  Future<Map<String, String>> _settings() async {
    final rows = await repo.db.select(repo.db.settings).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<void> _checkBudget(FinanceData fin, Txn t) async {
    final month = monthStart(t.occurredAt);
    if (!sameMonth(month, DateTime.now())) return;
    for (final st in fin.budgetStatuses(month)) {
      if (st.categoryId != 0 && st.categoryId != t.categoryId) continue;
      final name = st.categoryId == 0
          ? 'মোট'
          : (fin.catById[st.categoryId]?.name ?? '');
      for (final level in const [100, 80]) {
        if (st.ratio * 100 < level) continue;
        final key = 'alert_${monthKey(month)}_${st.categoryId}_$level';
        if (await repo.getSetting(key) != null) break;
        await repo.setSetting(key, '1');
        if (level == 100) {
          await Notify.instance.budgetAlert(
            st.categoryId,
            '🚨 $name বাজেট শেষ!',
            'এ মাসে ${money(st.spent)} খরচ হয়েছে, বাজেট ছিল ${money(st.limit)}',
          );
        } else {
          await Notify.instance.budgetAlert(
            st.categoryId,
            '⚠️ $name বাজেটের ${percent(st.ratio * 100)} শেষ',
            'বাকি আছে ${money(math.max(0, st.limit - st.spent))}',
          );
        }
        break;
      }
    }
  }

  Future<void> _scheduleDebt(FinanceData fin, Txn t) async {
    await Notify.instance.cancelDebt(t.id);
    final due = t.dueDate;
    final a = t.debtAction;
    if (due == null || a == null || t.personId == null) return;
    final p = fin.personById[t.personId]?.name ?? '';
    if (a == DebtAction.borrow) {
      await Notify.instance.scheduleDebt(
        t.id,
        due,
        '⏰ আজ $p-কে ধার শোধের দিন',
        '${money(t.amount)} নিয়েছিলেন ${dayLabel(t.occurredAt)}',
      );
    } else if (a == DebtAction.lend) {
      await Notify.instance.scheduleDebt(
        t.id,
        due,
        '⏰ আজ $p-এর কাছ থেকে টাকা ফেরত পাওয়ার দিন',
        '${money(t.amount)} দিয়েছিলেন ${dayLabel(t.occurredAt)}',
      );
    }
  }

  Future<void> refreshWidget([FinanceData? fin]) async {
    fin ??= await _fresh();
    final now = DateTime.now();
    final today = fin
        .inRange(DateRange(dayStart(now), dayStart(now).add(const Duration(days: 1))))
        .where((t) => t.type == TxType.expense)
        .fold(0, (s, t) => s + t.amount);
    final month = fin.monthSummary(now);
    await HomeWidgetService.update(
      todayExpense: today,
      monthExpense: month.expense,
      balance: fin.currentBalance,
    );
  }
}
