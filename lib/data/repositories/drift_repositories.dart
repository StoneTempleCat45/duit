import 'package:drift/drift.dart';

import '../../core/dates.dart';
import '../../domain/models.dart';
import '../db/app_database.dart';
import 'repositories.dart';

class DriftExpenseRepository implements ExpenseRepository {
  DriftExpenseRepository(this._db);

  final AppDatabase _db;

  static Expense _toDomain(ExpenseRow r) => Expense(
        id: r.id,
        amountCents: r.amountCents,
        categoryId: r.categoryId,
        note: r.note,
        day: parseDayKey(r.day),
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  static List<Expense> _mapAll(List<ExpenseRow> rows) => rows.map(_toDomain).toList();

  @override
  Stream<List<Expense>> watchBetween(DateTime from, DateTime to) {
    final query = _db.select(_db.expenses)
      ..where((e) => e.day.isBetweenValues(dayKey(from), dayKey(to)))
      ..orderBy([
        (e) => OrderingTerm.desc(e.day),
        (e) => OrderingTerm.desc(e.createdAt),
      ]);
    return query.watch().map(_mapAll);
  }

  @override
  Stream<List<Expense>> watchAll() {
    final query = _db.select(_db.expenses)
      ..orderBy([
        (e) => OrderingTerm.desc(e.day),
        (e) => OrderingTerm.desc(e.createdAt),
      ]);
    return query.watch().map(_mapAll);
  }

  @override
  Stream<int> watchTotalSince(DateTime from) {
    final total = _db.expenses.amountCents.sum();
    final query = _db.selectOnly(_db.expenses)
      ..addColumns([total])
      ..where(_db.expenses.day.isBiggerOrEqualValue(dayKey(from)));
    return query.map((row) => row.read(total) ?? 0).watchSingle();
  }

  @override
  Future<Expense?> getById(String id) async {
    final row = await (_db.select(_db.expenses)..where((e) => e.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(Expense e) async {
    await _db.into(_db.expenses).insertOnConflictUpdate(
          ExpensesCompanion.insert(
            id: e.id,
            amountCents: e.amountCents,
            categoryId: e.categoryId,
            note: Value(e.note),
            day: dayKey(e.day),
            createdAt: e.createdAt,
            updatedAt: e.updatedAt,
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();
  }
}

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Category>> watchAll() {
    final query = _db.select(_db.categories)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    return query.watch().map((rows) => rows
        .map((r) => Category(
              id: r.id,
              name: r.name,
              iconKey: r.iconKey,
              colorValue: r.colorValue,
              sortOrder: r.sortOrder,
            ))
        .toList());
  }
}

class DriftIncomeRepository implements IncomeRepository {
  DriftIncomeRepository(this._db);

  final AppDatabase _db;

  static Income _toDomain(IncomeRow r) => Income(
        id: r.id,
        amountCents: r.amountCents,
        sourceId: r.sourceId,
        note: r.note,
        day: parseDayKey(r.day),
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  static List<Income> _mapAll(List<IncomeRow> rows) => rows.map(_toDomain).toList();

  @override
  Stream<List<Income>> watchAll() {
    final query = _db.select(_db.incomes)
      ..orderBy([(i) => OrderingTerm.desc(i.day), (i) => OrderingTerm.desc(i.createdAt)]);
    return query.watch().map(_mapAll);
  }

  @override
  Stream<List<Income>> watchBetween(DateTime from, DateTime to) {
    final query = _db.select(_db.incomes)
      ..where((i) => i.day.isBetweenValues(dayKey(from), dayKey(to)))
      ..orderBy([(i) => OrderingTerm.desc(i.day), (i) => OrderingTerm.desc(i.createdAt)]);
    return query.watch().map(_mapAll);
  }

  @override
  Stream<int> watchTotalSince(DateTime from) {
    final total = _db.incomes.amountCents.sum();
    final query = _db.selectOnly(_db.incomes)
      ..addColumns([total])
      ..where(_db.incomes.day.isBiggerOrEqualValue(dayKey(from)));
    return query.map((row) => row.read(total) ?? 0).watchSingle();
  }

  @override
  Future<void> save(Income i) async {
    await _db.into(_db.incomes).insertOnConflictUpdate(IncomesCompanion.insert(
          id: i.id,
          amountCents: i.amountCents,
          sourceId: i.sourceId,
          note: Value(i.note),
          day: dayKey(i.day),
          createdAt: i.createdAt,
          updatedAt: i.updatedAt,
        ));
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.incomes)..where((i) => i.id.equals(id))).go();
  }
}

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db);

  final AppDatabase _db;

  static MonthlyBudget _monthToDomain(MonthlyBudgetRow r) => MonthlyBudget(
        month: r.month,
        amountCents: r.amountCents,
        carriedOver: r.carriedOver,
        warned80: r.warned80,
        warned100: r.warned100,
      );

  @override
  Stream<BudgetSettings?> watchSettings() {
    final query = _db.select(_db.appSettings)..where((s) => s.id.equals(1));
    return query.watchSingleOrNull().map((r) => r == null
        ? null
        : BudgetSettings(
            overallCents: r.overallCents,
            trackingStart: parseDayKey(r.trackingStart),
            potStart: parseDayKey(r.potStart ?? r.trackingStart),
            updatedAt: r.updatedAt,
          ));
  }

  @override
  Stream<MonthlyBudget?> watchMonth(String month) {
    final query = _db.select(_db.monthlyBudgets)..where((b) => b.month.equals(month));
    return query.watchSingleOrNull().map((r) => r == null ? null : _monthToDomain(r));
  }

  @override
  Future<void> completeSetup({
    required int overallCents,
    required int monthlyCents,
    required DateTime today,
  }) {
    return _db.transaction(() async {
      final now = DateTime.now();
      await setMonthBudget(monthKey(today), monthlyCents);
      await _db.into(_db.appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(
            id: const Value(1),
            overallCents: overallCents,
            trackingStart: dayKey(today),
            potStart: const Value(null),
            updatedAt: now,
          ));
    });
  }

  @override
  Future<void> startNewOverall({required int overallCents, required DateTime today}) async {
    await (_db.update(_db.appSettings)..where((s) => s.id.equals(1))).write(
      AppSettingsCompanion(
        overallCents: Value(overallCents),
        potStart: Value(dayKey(today)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteAllData() {
    return _db.transaction(() async {
      await _db.delete(_db.expenses).go();
      await _db.delete(_db.incomes).go();
      await _db.delete(_db.monthlyBudgets).go();
      await _db.delete(_db.appSettings).go();
    });
  }

  @override
  Future<void> extendTrackingStart(DateTime day) async {
    final key = dayKey(day);
    await (_db.update(_db.appSettings)
          ..where((s) => s.id.equals(1) & s.trackingStart.isBiggerThanValue(key)))
        .write(AppSettingsCompanion(trackingStart: Value(key), updatedAt: Value(DateTime.now())));
  }

  @override
  Future<void> updateOverall(int overallCents) async {
    await (_db.update(_db.appSettings)..where((s) => s.id.equals(1))).write(
      AppSettingsCompanion(
        overallCents: Value(overallCents),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> setMonthBudget(String month, int cents) async {
    // Changing the amount re-arms the 80% / 100% warnings for this month.
    await _db.into(_db.monthlyBudgets).insertOnConflictUpdate(MonthlyBudgetsCompanion.insert(
          month: month,
          amountCents: cents,
          carriedOver: const Value(false),
          warned80: const Value(false),
          warned100: const Value(false),
          updatedAt: DateTime.now(),
        ));
  }

  @override
  Future<void> ensureMonth(String month) {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.monthlyBudgets)..where((b) => b.month.equals(month)))
          .getSingleOrNull();
      if (existing != null) return;

      final previous = await (_db.select(_db.monthlyBudgets)
            ..where((b) => b.month.isSmallerThanValue(month))
            ..orderBy([(b) => OrderingTerm.desc(b.month)])
            ..limit(1))
          .getSingleOrNull();
      if (previous == null) return; // setup not finished yet

      await _db.into(_db.monthlyBudgets).insert(
            MonthlyBudgetsCompanion.insert(
              month: month,
              amountCents: previous.amountCents,
              carriedOver: const Value(true),
              updatedAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }

  @override
  Future<void> acknowledgeCarryOver(String month) async {
    await (_db.update(_db.monthlyBudgets)..where((b) => b.month.equals(month))).write(
      const MonthlyBudgetsCompanion(carriedOver: Value(false)),
    );
  }

  @override
  Future<void> markWarned(String month, {bool? warned80, bool? warned100}) async {
    await (_db.update(_db.monthlyBudgets)..where((b) => b.month.equals(month))).write(
      MonthlyBudgetsCompanion(
        warned80: warned80 == null ? const Value.absent() : Value(warned80),
        warned100: warned100 == null ? const Value.absent() : Value(warned100),
      ),
    );
  }
}
