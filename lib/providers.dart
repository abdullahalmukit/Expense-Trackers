import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/dates.dart';
import 'data/database.dart';
import 'data/repo.dart';
import 'domain/finance.dart';
import 'services/effects.dart';

/// main() এ override করা হয়।
final dbProvider = Provider<AppDb>((ref) => throw UnimplementedError());
final repoProvider = Provider<Repo>((ref) => Repo(ref.watch(dbProvider)));

final categoriesProvider = StreamProvider<List<Cat>>(
  (ref) => ref.watch(repoProvider).watchCategories(),
);
final txnsProvider = StreamProvider<List<Txn>>((ref) => ref.watch(repoProvider).watchTxns());
final personsProvider = StreamProvider<List<Person>>(
  (ref) => ref.watch(repoProvider).watchPersons(),
);
final walletsProvider = StreamProvider<List<Wallet>>(
  (ref) => ref.watch(repoProvider).watchWallets(),
);
final transfersProvider = StreamProvider<List<Transfer>>(
  (ref) => ref.watch(repoProvider).watchTransfers(),
);
final budgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(repoProvider).watchBudgets(),
);
final goalsProvider = StreamProvider<List<Goal>>((ref) => ref.watch(repoProvider).watchGoals());
final recurringsProvider = StreamProvider<List<Recurring>>(
  (ref) => ref.watch(repoProvider).watchRecurrings(),
);
final settingsProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(repoProvider).watchSettings(),
);

/// সব তালিকা মিলিয়ে হিসাবের অবজেক্ট — যেকোনো পরিবর্তনে নতুন করে গণনা।
final financeProvider = Provider<FinanceData>((ref) {
  final txns = ref.watch(txnsProvider).value;
  final cats = ref.watch(categoriesProvider).value;
  if (txns == null || cats == null) return FinanceData.empty();
  return FinanceData(
    txns: txns,
    cats: cats,
    persons: ref.watch(personsProvider).value ?? const [],
    wallets: ref.watch(walletsProvider).value ?? const [],
    transfers: ref.watch(transfersProvider).value ?? const [],
    budgets: ref.watch(budgetsProvider).value ?? const [],
  );
});

final dataReadyProvider = Provider<bool>(
  (ref) =>
      ref.watch(txnsProvider).hasValue &&
      ref.watch(categoriesProvider).hasValue &&
      ref.watch(settingsProvider).hasValue,
);

/// সাধারণ মান রাখার Notifier
class ValueNotifierX<T> extends Notifier<T> {
  ValueNotifierX(this._initial);
  final T _initial;
  @override
  T build() => _initial;
  void set(T v) => state = v;
}

/// হোম/হিস্টোরির নির্বাচিত মাস
final selectedMonthProvider = NotifierProvider<ValueNotifierX<DateTime>, DateTime>(
  () => ValueNotifierX(monthStart(DateTime.now())),
);

final tabIndexProvider = NotifierProvider<ValueNotifierX<int>, int>(() => ValueNotifierX(0));

class AppSettings {
  final Map<String, String> raw;
  const AppSettings(this.raw);

  ThemeMode get themeMode => switch (raw['theme']) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  /// ভাষা বাছাই করা হয়েছে কিনা (প্রথমবার খুললে জিজ্ঞেস করা হয়)
  bool get languageChosen => raw['lang'] != null;
  bool get english => raw['lang'] == 'en';

  /// আলাদা করে সেট না করলে সংখ্যা ভাষার সাথে মিলিয়ে
  bool get bengaliDigits => raw['digits'] == null ? !english : raw['digits'] != 'en';
  bool get lockEnabled => raw['lock_pin'] != null;
  bool get lockBiometric => raw['lock_bio'] == '1';
  bool get reminderEnabled => raw['reminder'] == '1';
  TimeOfDay get reminderTime {
    final p = (raw['reminder_time'] ?? '21:00').split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String get autoBackup => raw['auto_backup'] ?? 'weekly';
  bool get budgetAlerts => raw['budget_alerts'] != '0';
  bool get debtReminders => raw['debt_reminders'] != '0';
  bool get statsIncludeDebt => raw['stats_debt'] != '0';
  DateTime? get lastBackup => DateTime.tryParse(raw['last_backup'] ?? '');
}

final appSettingsProvider = Provider<AppSettings>(
  (ref) => AppSettings(ref.watch(settingsProvider).value ?? const {}),
);

final effectsProvider = Provider<Effects>((ref) => Effects(ref.watch(repoProvider)));
