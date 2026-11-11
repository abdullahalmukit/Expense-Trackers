import 'dart:math' as math;

import '../core/dates.dart';
import '../core/i18n.dart';
import '../core/money.dart';
import '../data/database.dart';

class TxType {
  static const expense = 0;
  static const income = 1;
  static String label(int t) => t == expense ? tr('খরচ', 'Expense') : tr('জমা', 'Income');
}

/// ধারের চার ধরন। নিলাম/ফেরত পেলাম = জমা, দিলাম/শোধ করলাম = খরচ।
class DebtAction {
  static const borrow = 0; // ধার নিলাম
  static const repay = 1; // নেওয়া ধার শোধ করলাম
  static const lend = 2; // ধার দিলাম
  static const collect = 3; // দেওয়া ধার ফেরত পেলাম

  static const bnLabels = ['নিলাম', 'শোধ করলাম', 'দিলাম', 'ফেরত পেলাম'];
  static const enLabels = ['Borrowed', 'Repaid', 'Lent', 'Got back'];
  static const bnFull = ['ধার নিলাম', 'ধার শোধ করলাম', 'ধার দিলাম', 'ধার ফেরত পেলাম'];
  static const enFull = ['Borrowed', 'Repaid a loan', 'Lent', 'Got loan back'];
  static String label(int a) => Lang.en ? enLabels[a] : bnLabels[a];
  static String fullLabel(int a) => Lang.en ? enFull[a] : bnFull[a];

  static int typeOf(int a) => (a == borrow || a == collect) ? TxType.income : TxType.expense;

  /// খরচে 'দিলাম / শোধ করলাম', জমায় 'নিলাম / ফেরত পেলাম'
  static List<int> forType(int type) =>
      type == TxType.expense ? const [lend, repay] : const [borrow, collect];

  static int? parse(String s) {
    final t = s.trim();
    final low = t.toLowerCase();
    for (var i = 0; i < 4; i++) {
      if (t == bnLabels[i] || t == bnFull[i]) return i;
      if (low == enLabels[i].toLowerCase() || low == enFull[i].toLowerCase()) return i;
    }
    const en = ['borrow', 'repay', 'lend', 'collect'];
    final i = en.indexOf(low);
    return i >= 0 ? i : int.tryParse(t);
  }
}

class MonthSummary {
  final DateTime month;
  final int opening;
  final int income;
  final int expense;
  final int debtIncome;
  final int debtExpense;
  const MonthSummary({
    required this.month,
    required this.opening,
    required this.income,
    required this.expense,
    required this.debtIncome,
    required this.debtExpense,
  });
  int get closing => opening + income - expense;
  int get net => income - expense;
  int get realIncome => income - debtIncome;
  int get realExpense => expense - debtExpense;
}

class PersonDebt {
  final Person person;
  int borrowed = 0; // নিলাম
  int repaid = 0; // শোধ করলাম
  int lent = 0; // দিলাম
  int collected = 0; // ফেরত পেলাম
  DateTime? lastAt;
  DateTime? nextDue;
  int count = 0;
  PersonDebt(this.person);

  /// আমি দেব
  int get payable => borrowed - repaid;

  /// আমি পাব
  int get receivable => lent - collected;
  bool get settled => payable == 0 && receivable == 0;
}

class LedgerRow {
  final Txn txn;

  /// এই এন্ট্রির পরে বাকি (নিলাম/শোধ হলে দেনা, দিলাম/ফেরত হলে পাওনা)
  final int remaining;
  const LedgerRow(this.txn, this.remaining);
}

class BudgetStatus {
  final int categoryId; // 0 = মোট
  final int limit;
  final int spent;
  const BudgetStatus(this.categoryId, this.limit, this.spent);
  double get ratio => limit <= 0 ? 0 : spent / limit;
}

class MonthTotals {
  final DateTime month;
  final int income;
  final int expense;
  const MonthTotals(this.month, this.income, this.expense);
  int get saving => income - expense;
}

final tagRegex = RegExp(r'#[\p{L}\p{M}\p{N}_]+', unicode: true);

Set<String> tagsOf(Txn t) => {
  ...tagRegex.allMatches(t.note).map((m) => m[0]!),
  ...tagRegex.allMatches(t.purpose).map((m) => m[0]!),
};

/// সব হিসাব ফোনেই — কোনো মোট আলাদা টেবিলে রাখা হয় না, সব এন্ট্রি থেকে গণনা।
class FinanceData {
  /// নতুন আগে (occurredAt অনুযায়ী)
  final List<Txn> txns;
  final List<Cat> cats;
  final List<Person> persons;
  final List<Wallet> wallets;
  final List<Transfer> transfers;
  final List<Budget> budgets;

  late final Map<int, Cat> catById = {for (final c in cats) c.id: c};
  late final Map<int, Person> personById = {for (final p in persons) p.id: p};
  late final Map<int, Wallet> walletById = {for (final w in wallets) w.id: w};

  FinanceData({
    required List<Txn> txns,
    required this.cats,
    required this.persons,
    required this.wallets,
    required this.transfers,
    required this.budgets,
  }) : txns = [...txns]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  static FinanceData empty() => FinanceData(
    txns: const [],
    cats: const [],
    persons: const [],
    wallets: const [],
    transfers: const [],
    budgets: const [],
  );

  int get openingTotal => wallets.fold(0, (s, w) => s + w.openingBalance);

  static int signed(Txn t) => t.type == TxType.income ? t.amount : -t.amount;

  bool _incl(Txn t, bool includeDebt) => includeDebt || t.debtAction == null;

  Iterable<Txn> inRange(DateRange r, {bool includeDebt = true}) =>
      txns.where((t) => r.contains(t.occurredAt) && _incl(t, includeDebt));

  int sumOf(Iterable<Txn> list, int type) =>
      list.where((t) => t.type == type).fold(0, (s, t) => s + t.amount);

  int balanceBefore(DateTime d) {
    var b = openingTotal;
    for (final t in txns) {
      if (t.occurredAt.isBefore(d)) b += signed(t);
    }
    return b;
  }

  int get currentBalance => openingTotal + txns.fold(0, (s, t) => s + signed(t));

  MonthSummary monthSummary(DateTime m) {
    final r = DateRange.month(m);
    final list = inRange(r).toList();
    final debt = list.where((t) => t.debtAction != null);
    return MonthSummary(
      month: r.start,
      opening: balanceBefore(r.start),
      income: sumOf(list, TxType.income),
      expense: sumOf(list, TxType.expense),
      debtIncome: sumOf(debt, TxType.income),
      debtExpense: sumOf(debt, TxType.expense),
    );
  }

  /// প্রতিটি ওয়ালেটের বর্তমান ব্যালেন্স (ট্রান্সফার সহ)।
  /// walletId না থাকা এন্ট্রি প্রথম ওয়ালেটে ধরা হয়।
  Map<int, int> walletBalances() {
    final out = {for (final w in wallets) w.id: w.openingBalance};
    final fallback = wallets.isEmpty ? null : wallets.first.id;
    for (final t in txns) {
      final id = (t.walletId != null && out.containsKey(t.walletId)) ? t.walletId : fallback;
      if (id != null) out[id] = out[id]! + signed(t);
    }
    for (final tr in transfers) {
      if (out.containsKey(tr.fromWalletId)) {
        out[tr.fromWalletId] = out[tr.fromWalletId]! - tr.amount;
      }
      if (out.containsKey(tr.toWalletId)) {
        out[tr.toWalletId] = out[tr.toWalletId]! + tr.amount;
      }
    }
    return out;
  }

  // ---------------- ধার ----------------

  List<PersonDebt> debts() {
    final map = <int, PersonDebt>{};
    for (final t in txns) {
      final a = t.debtAction;
      final pid = t.personId;
      if (a == null || pid == null) continue;
      final p = personById[pid];
      if (p == null) continue;
      final d = map.putIfAbsent(pid, () => PersonDebt(p));
      d.count++;
      switch (a) {
        case DebtAction.borrow:
          d.borrowed += t.amount;
        case DebtAction.repay:
          d.repaid += t.amount;
        case DebtAction.lend:
          d.lent += t.amount;
        case DebtAction.collect:
          d.collected += t.amount;
      }
      if (d.lastAt == null || t.occurredAt.isAfter(d.lastAt!)) {
        d.lastAt = t.occurredAt;
      }
      final due = t.dueDate;
      if (due != null && (d.nextDue == null || due.isBefore(d.nextDue!))) {
        d.nextDue = due;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0)));
    for (final d in list) {
      if (d.settled) d.nextDue = null;
    }
    return list;
  }

  int get totalPayable => debts().fold(0, (s, d) => s + math.max(0, d.payable));
  int get totalReceivable => debts().fold(0, (s, d) => s + math.max(0, d.receivable));

  /// ব্যক্তির পুরো হিস্টোরি, নতুনটা উপরে, প্রতিটির পরে কত বাকি।
  List<LedgerRow> ledger(int personId) {
    final list = txns.where((t) => t.personId == personId && t.debtAction != null).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    var payable = 0, receivable = 0;
    final rows = <LedgerRow>[];
    for (final t in list) {
      switch (t.debtAction!) {
        case DebtAction.borrow:
          payable += t.amount;
        case DebtAction.repay:
          payable -= t.amount;
        case DebtAction.lend:
          receivable += t.amount;
        case DebtAction.collect:
          receivable -= t.amount;
      }
      final side = (t.debtAction == DebtAction.borrow || t.debtAction == DebtAction.repay)
          ? payable
          : receivable;
      rows.add(LedgerRow(t, side));
    }
    return rows.reversed.toList();
  }

  // ---------------- পরিসংখ্যান ----------------

  Map<int, int> categoryTotals(DateRange r, int type, {bool includeDebt = true}) {
    final out = <int, int>{};
    for (final t in inRange(r, includeDebt: includeDebt)) {
      if (t.type != type) continue;
      out[t.categoryId] = (out[t.categoryId] ?? 0) + t.amount;
    }
    return out;
  }

  /// পরিসরের প্রতিদিনের মোট (index 0 = r.start)
  List<int> dailyTotals(DateRange r, int type, {bool includeDebt = true}) {
    final days = math.max(1, r.days);
    final out = List<int>.filled(days, 0);
    for (final t in inRange(r, includeDebt: includeDebt)) {
      if (t.type != type) continue;
      final i = dayStart(t.occurredAt).difference(r.start).inDays;
      if (i >= 0 && i < days) out[i] += t.amount;
    }
    return out;
  }

  /// মাসের প্রতিদিন পর্যন্ত ক্রমযোজিত খরচ
  List<int> cumulative(DateTime month, int type, {bool includeDebt = true}) {
    final daily = dailyTotals(DateRange.month(month), type, includeDebt: includeDebt);
    var s = 0;
    return [for (final v in daily) s += v];
  }

  List<MonthTotals> monthlySeries({bool includeDebt = true, DateTime? from, DateTime? to}) {
    if (txns.isEmpty) return const [];
    final first = from ?? monthStart(txns.last.occurredAt);
    final last = to ?? monthStart(DateTime.now());
    final out = <MonthTotals>[];
    var m = monthStart(first);
    while (!m.isAfter(last)) {
      final list = inRange(DateRange.month(m), includeDebt: includeDebt);
      out.add(MonthTotals(m, sumOf(list, TxType.income), sumOf(list, TxType.expense)));
      m = nextMonth(m);
    }
    return out;
  }

  /// ক্যাটাগরি বাছাইয়ের গ্রিডে বেশি ব্যবহৃত আগে
  Map<int, int> usageCounts() {
    final out = <int, int>{};
    final since = DateTime.now().subtract(const Duration(days: 120));
    for (final t in txns) {
      if (t.occurredAt.isBefore(since)) break;
      out[t.categoryId] = (out[t.categoryId] ?? 0) + 1;
    }
    return out;
  }

  // ---------------- বাজেট ----------------

  /// এই মাসে প্রযোজ্য বাজেট: month <= এই মাস এমন সর্বশেষ সেটিং।
  int? budgetFor(DateTime month, int categoryId) {
    final key = monthKey(month);
    Budget? best;
    for (final b in budgets) {
      if (b.categoryId != categoryId) continue;
      if (b.month.compareTo(key) > 0) continue;
      if (best == null || b.month.compareTo(best.month) > 0) best = b;
    }
    if (best == null || best.limitAmount <= 0) return null;
    return best.limitAmount;
  }

  List<BudgetStatus> budgetStatuses(DateTime month) {
    final ids = budgets.map((b) => b.categoryId).toSet();
    final totals = categoryTotals(DateRange.month(month), TxType.expense);
    final totalSpent = totals.values.fold(0, (s, v) => s + v);
    final out = <BudgetStatus>[];
    for (final id in ids) {
      final limit = budgetFor(month, id);
      if (limit == null) continue;
      if (id != 0 && catById[id] == null) continue;
      out.add(BudgetStatus(id, limit, id == 0 ? totalSpent : (totals[id] ?? 0)));
    }
    out.sort((a, b) {
      if (a.categoryId == 0) return -1;
      if (b.categoryId == 0) return 1;
      return b.ratio.compareTo(a.ratio);
    });
    return out;
  }

  // ---------------- ট্যাগ ----------------

  Map<String, int> tagTotals({int type = TxType.expense}) {
    final out = <String, int>{};
    for (final t in txns) {
      if (t.type != type) continue;
      for (final tag in tagsOf(t)) {
        out[tag] = (out[tag] ?? 0) + t.amount;
      }
    }
    return out;
  }

  Set<String> get allTags => {for (final t in txns) ...tagsOf(t)};

  // ---------------- ইনসাইট ----------------

  List<String> insights(DateTime month, {DateTime? now}) {
    now ??= DateTime.now();
    final out = <String>[];
    final isCurrent = sameMonth(month, now);
    final dayLimit = isCurrent ? now.day : daysInMonth(month);
    final thisR = DateRange(monthStart(month), DateTime(month.year, month.month, dayLimit + 1));
    final prev = prevMonth(month);
    final prevDay = math.min(dayLimit, daysInMonth(prev));
    final prevR = DateRange(monthStart(prev), DateTime(prev.year, prev.month, prevDay + 1));
    final cur = categoryTotals(thisR, TxType.expense, includeDebt: false);
    final old = categoryTotals(prevR, TxType.expense, includeDebt: false);
    final when = isCurrent
        ? tr('গত মাসের এই সময়ের', 'this time last month')
        : tr('গত মাসের', 'last month');

    // সবচেয়ে বেশি বেড়েছে এমন ক্যাটাগরি
    String? up;
    var upDiff = 0;
    String? down;
    var downDiff = 0;
    for (final id in {...cur.keys, ...old.keys}) {
      final c = cur[id] ?? 0, o = old[id] ?? 0;
      final name = catById[id]?.name;
      if (name == null) continue;
      final diff = c - o;
      if (o > 0 && diff > 20000 && diff / o > 0.2 && diff > upDiff) {
        upDiff = diff;
        up = tr(
          'এ মাসে $name-এ $when চেয়ে ${money(diff)} (${percent(diff / o * 100)}) বেশি খরচ হচ্ছে',
          'Spending on $name is ${money(diff)} (${percent(diff / o * 100)}) higher than $when',
        );
      }
      if (o > 0 && -diff > 20000 && -diff / o > 0.2 && -diff > downDiff) {
        downDiff = -diff;
        down = tr(
          '$name-এ খরচ $when চেয়ে ${money(-diff)} কম — ভালো চলছে!',
          '$name spending is ${money(-diff)} lower than $when — nice!',
        );
      }
    }
    if (up != null) out.add('📈 $up');

    final curTotal = cur.values.fold(0, (s, v) => s + v);
    final oldTotal = old.values.fold(0, (s, v) => s + v);
    if (oldTotal > 0 && curTotal > 0) {
      final pct = (curTotal - oldTotal) / oldTotal * 100;
      if (pct.abs() >= 10) {
        out.add(
          pct > 0
              ? tr(
                  '⚠️ মোট খরচ $when চেয়ে ${percent(pct)} বেশি',
                  '⚠️ Total spending is ${percent(pct)} higher than $when',
                )
              : tr(
                  '✅ মোট খরচ $when চেয়ে ${percent(-pct)} কম',
                  '✅ Total spending is ${percent(-pct)} lower than $when',
                ),
        );
      }
    }
    if (down != null) out.add('👏 $down');

    final total = budgetFor(month, 0);
    if (total != null && isCurrent) {
      final spent = categoryTotals(
        DateRange.month(month),
        TxType.expense,
      ).values.fold(0, (s, v) => s + v);
      final left = daysInMonth(month) - now.day;
      final r = spent / total;
      if (r >= 1) {
        out.add(
          tr(
            '🚨 এ মাসের বাজেট ${money(spent - total)} পার হয়ে গেছে',
            '🚨 This month\'s budget is exceeded by ${money(spent - total)}',
          ),
        );
      } else if (r >= 0.7) {
        out.add(
          tr(
            '💡 বাজেটের ${percent(r * 100)} শেষ, মাসের বাকি ${dg(left)} দিন — দিনে ${money(((total - spent) / math.max(1, left)).round())} করে খরচ করা যাবে',
            '💡 ${percent(r * 100)} of the budget used with ${dg(left)} days left — you can spend ${money(((total - spent) / math.max(1, left)).round())} a day',
          ),
        );
      }
    }

    if (curTotal > 0) {
      final avg = (curTotal / dayLimit).round();
      out.add(
        tr(
          '📊 এ মাসে গড়ে দিনে ${money(avg)} খরচ হচ্ছে (ধার ছাড়া)',
          '📊 You\'re spending ${money(avg)} a day on average this month (excl. debt)',
        ),
      );
    }

    final big = inRange(thisR, includeDebt: false)
        .where((t) => t.type == TxType.expense)
        .fold<Txn?>(null, (m, t) => m == null || t.amount > m.amount ? t : m);
    if (big != null && curTotal > 0 && big.amount / curTotal > 0.25) {
      final n = catById[big.categoryId]?.name ?? '';
      out.add(
        tr(
          '🔎 এ মাসের সবচেয়ে বড় খরচ: $n — ${money(big.amount)}',
          '🔎 Biggest expense this month: $n — ${money(big.amount)}',
        ),
      );
    }

    for (final d in debts()) {
      if (d.nextDue != null && !d.nextDue!.isAfter(now.add(const Duration(days: 3)))) {
        final amt = d.payable > 0 ? d.payable : d.receivable;
        final what = d.payable > 0 ? tr('শোধের', 'repayment') : tr('ফেরত পাওয়ার', 'collection');
        out.add(
          tr(
            '⏰ ${d.person.name}-এর ${money(amt)} $what তারিখ ${dayLabel(d.nextDue!)}',
            '⏰ ${d.person.name}: ${money(amt)} $what due ${dayLabel(d.nextDue!)}',
          ),
        );
        break;
      }
    }
    return out.take(4).toList();
  }
}
