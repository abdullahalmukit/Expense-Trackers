import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// ক্যাটাগরি — kind: 0 = খরচ, 1 = জমা। isDebt = সিস্টেমের 'ধার' ক্যাটাগরি।
@DataClassName('Cat')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get color => integer()();
  IntColumn get kind => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDebt => boolean().withDefault(const Constant(false))();
}

/// প্রতিটি এন্ট্রি। টাকা পয়সায় পূর্ণসংখ্যা (১২.৫০ ৳ = 1250)।
/// type: 0 = খরচ, 1 = জমা। debtAction: 0 নিলাম, 1 শোধ করলাম, 2 দিলাম, 3 ফেরত পেলাম।
@DataClassName('Txn')
class Transactions extends Table {
  TextColumn get id => text()();
  IntColumn get type => integer()();
  IntColumn get amount => integer()();
  IntColumn get categoryId => integer()();
  IntColumn get debtAction => integer().nullable()();
  IntColumn get personId => integer().nullable()();
  IntColumn get walletId => integer().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get purpose => text().withDefault(const Constant(''))();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Person')
class Persons extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

@DataClassName('Wallet')
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// এক ওয়ালেট থেকে আরেকটায় ট্রান্সফার — খরচ বা জমা হিসেবে গোনা হয় না।
@DataClassName('Transfer')
class Transfers extends Table {
  TextColumn get id => text()();
  IntColumn get fromWalletId => integer()();
  IntColumn get toWalletId => integer()();
  IntColumn get amount => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// মাসিক বাজেট। month = 'YYYY-MM' (এই মাস থেকে পরের সব মাসে প্রযোজ্য, যতক্ষণ না নতুন সেট হয়)।
/// categoryId = 0 মানে মোট বাজেট।
@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get month => text()();
  IntColumn get categoryId => integer()();
  IntColumn get limitAmount => integer()();
}

@DataClassName('Goal')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get color => integer()();
  IntColumn get target => integer()();
  IntColumn get saved => integer().withDefault(const Constant(0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// রিকারিং এন্ট্রি — প্রতি মাসের নির্দিষ্ট দিনে নিজে থেকে যোগ হবে বা মনে করাবে।
@DataClassName('Recurring')
class Recurrings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get type => integer()();
  IntColumn get amount => integer()();
  IntColumn get categoryId => integer()();
  IntColumn get walletId => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get dayOfMonth => integer()();
  BoolColumn get autoAdd => boolean().withDefault(const Constant(true))();
  DateTimeColumn get nextDate => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Categories,
    Transactions,
    Persons,
    Wallets,
    Transfers,
    Budgets,
    Goals,
    Recurrings,
    Settings,
  ],
)
class AppDb extends _$AppDb {
  AppDb([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'takar_khata'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_txn_occurred ON transactions (occurred_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_txn_person ON transactions (person_id)',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = OFF');
    },
  );

  /// সব টেবিল খালি করা (ইমপোর্টে 'সব বদলে দিন' এর জন্য)।
  Future<void> wipeAll({bool keepSettings = true}) async {
    await transaction(() async {
      await delete(transactions).go();
      await delete(transfers).go();
      await delete(categories).go();
      await delete(persons).go();
      await delete(wallets).go();
      await delete(budgets).go();
      await delete(goals).go();
      await delete(recurrings).go();
      if (!keepSettings) await delete(settings).go();
    });
  }
}
