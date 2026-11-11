import 'package:flutter_test/flutter_test.dart';
import 'package:takar_khata/data/database.dart';
import 'package:takar_khata/domain/finance.dart';

Txn tx(String id, int type, int taka, int cat, DateTime at, {int? debt, int? person}) => Txn(
  id: id,
  type: type,
  amount: taka * 100,
  categoryId: cat,
  debtAction: debt,
  personId: person,
  walletId: 1,
  occurredAt: at,
  note: '',
  purpose: '',
  photoPath: null,
  dueDate: null,
  createdAt: at,
  updatedAt: at,
);

void main() {
  final cats = [
    const Cat(id: 1, name: 'খাবার', emoji: '🍛', color: 0, kind: 0, sortOrder: 0, archived: false, isDebt: false),
    const Cat(id: 2, name: 'টিউশন', emoji: '👨‍🏫', color: 0, kind: 1, sortOrder: 0, archived: false, isDebt: false),
    const Cat(id: 3, name: 'ধার', emoji: '🤝', color: 0, kind: 0, sortOrder: 99, archived: false, isDebt: true),
    const Cat(id: 4, name: 'ধার', emoji: '🤝', color: 0, kind: 1, sortOrder: 99, archived: false, isDebt: true),
  ];
  const rafi = Person(id: 1, name: 'রাফি', phone: '', note: '');
  const sakib = Person(id: 2, name: 'সাকিব', phone: '', note: '');
  const wallet = Wallet(id: 1, name: 'ক্যাশ', emoji: '💵', openingBalance: 100000, sortOrder: 0, archived: false);

  FinanceData make(List<Txn> txns, {List<Budget> budgets = const []}) => FinanceData(
    txns: txns,
    cats: cats,
    persons: [rafi, sakib],
    wallets: [wallet],
    transfers: const [],
    budgets: budgets,
  );

  test('রাফির কাছ থেকে নিয়েছি — প্রস্তাবনার উদাহরণ', () {
    final fin = make([
      tx('a', 1, 1000, 4, DateTime(2026, 11, 1), debt: DebtAction.borrow, person: 1),
      tx('b', 0, 500, 3, DateTime(2026, 11, 5), debt: DebtAction.repay, person: 1),
      tx('c', 0, 200, 3, DateTime(2026, 11, 10), debt: DebtAction.repay, person: 1),
    ]);
    final rows = fin.ledger(1);
    expect(rows.map((r) => r.txn.id), ['c', 'b', 'a']); // নতুনটা উপরে
    expect(rows.map((r) => r.remaining ~/ 100), [300, 500, 1000]);
    final d = fin.debts().single;
    expect(d.payable, 30000);
    expect(d.receivable, 0);
    expect(d.settled, false);
  });

  test('সাকিবকে দিয়েছি — প্রস্তাবনার উদাহরণ', () {
    final fin = make([
      tx('a', 0, 200, 3, DateTime(2026, 11, 3), debt: DebtAction.lend, person: 2),
      tx('b', 1, 100, 4, DateTime(2026, 11, 9), debt: DebtAction.collect, person: 2),
    ]);
    expect(fin.ledger(2).map((r) => r.remaining ~/ 100), [100, 200]);
    expect(fin.totalReceivable, 10000);
    expect(fin.totalPayable, 0);
  });

  test('বাকি শূন্য হলে মীমাংসিত', () {
    final fin = make([
      tx('a', 1, 500, 4, DateTime(2026, 11, 1), debt: DebtAction.borrow, person: 1),
      tx('b', 0, 500, 3, DateTime(2026, 11, 2), debt: DebtAction.repay, person: 1),
    ]);
    expect(fin.debts().single.settled, true);
  });

  test('মাসিক হিসাব — শুরুর ব্যালেন্স আগের মাস থেকে, ধার সহ মোট', () {
    final fin = make([
      tx('o1', 1, 5000, 2, DateTime(2026, 10, 3)),
      tx('o2', 0, 2000, 1, DateTime(2026, 10, 20)),
      tx('n1', 0, 300, 1, DateTime(2026, 11, 2)),
      tx('n2', 1, 1000, 4, DateTime(2026, 11, 4), debt: DebtAction.borrow, person: 1),
    ]);
    final s = fin.monthSummary(DateTime(2026, 11));
    expect(s.opening, (1000 + 5000 - 2000) * 100);
    expect(s.income, 100000);
    expect(s.expense, 30000);
    expect(s.realIncome, 0);
    expect(s.closing, (4000 + 1000 - 300) * 100);
    expect(fin.currentBalance, s.closing);
  });

  test('বাজেট পরের মাসগুলোতেও প্রযোজ্য', () {
    final fin = make(
      [tx('x', 0, 800, 1, DateTime(2026, 11, 2))],
      budgets: [
        const Budget(id: 1, month: '2026-09', categoryId: 1, limitAmount: 100000),
        const Budget(id: 2, month: '2026-12', categoryId: 1, limitAmount: 50000),
      ],
    );
    expect(fin.budgetFor(DateTime(2026, 11), 1), 100000);
    expect(fin.budgetFor(DateTime(2027, 1), 1), 50000);
    expect(fin.budgetFor(DateTime(2026, 8), 1), null);
    final st = fin.budgetStatuses(DateTime(2026, 11)).single;
    expect(st.ratio, closeTo(.8, 1e-9));
  });

  test('ট্যাগ', () {
    final t = tx('t', 0, 100, 1, DateTime(2026, 11, 2)).copyWith(note: 'বাস ভাড়া #ট্যুর #কক্সবাজার');
    final fin = make([t]);
    expect(tagsOf(t), {'#ট্যুর', '#কক্সবাজার'});
    expect(fin.tagTotals()['#ট্যুর'], 10000);
  });

  test('দৈনিক ও ক্রমযোজিত', () {
    final fin = make([
      tx('a', 0, 100, 1, DateTime(2026, 11, 1, 10)),
      tx('b', 0, 50, 1, DateTime(2026, 11, 1, 20)),
      tx('c', 0, 30, 1, DateTime(2026, 11, 3)),
    ]);
    final cum = fin.cumulative(DateTime(2026, 11), TxType.expense);
    expect(cum.length, 30);
    expect(cum[0], 15000);
    expect(cum[2], 18000);
    expect(cum.last, 18000);
  });
}
