import 'package:drift/drift.dart';

// Each class below becomes one SQLite table. Drift generates the code in
// app_database.g.dart when you run: dart run build_runner build

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get iconKey => text()();
  IntColumn get colorValue => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ExpenseRow')
@TableIndex(name: 'expenses_day', columns: {#day})
class Expenses extends Table {
  TextColumn get id => text()();

  /// Stored as whole cents so totals are always exact.
  IntColumn get amountCents => integer()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note => text().nullable()();

  /// "yyyy-MM-dd". Text dates sort correctly and never shift with time zones.
  TextColumn get day => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Money coming in (allowance, salary, freelance...). It adds to the overall
/// budget. Added in schema version 3.
@DataClassName('IncomeRow')
@TableIndex(name: 'incomes_day', columns: {#day})
class Incomes extends Table {
  TextColumn get id => text()();
  IntColumn get amountCents => integer()();

  /// One of the ids in lib/domain/income_sources.dart, e.g. "allowance".
  TextColumn get sourceId => text()();
  TextColumn get note => text().nullable()();

  /// "yyyy-MM-dd"
  TextColumn get day => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MonthlyBudgetRow')
class MonthlyBudgets extends Table {
  /// "yyyy-MM"
  TextColumn get month => text()();
  IntColumn get amountCents => integer()();
  BoolColumn get carriedOver => boolean().withDefault(const Constant(false))();
  BoolColumn get warned80 => boolean().withDefault(const Constant(false))();
  BoolColumn get warned100 => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {month};
}

/// A single row (id = 1) holding the overall budget.
@DataClassName('SettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get overallCents => integer()();

  /// "yyyy-MM-dd". The day the app was set up; the first month starts here.
  TextColumn get trackingStart => text()();

  /// "yyyy-MM-dd". The day the current overall budget started. Null means the
  /// same as [trackingStart]. Set when you start a new overall budget.
  /// Added in schema version 2.
  TextColumn get potStart => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
