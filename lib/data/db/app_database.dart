import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/default_categories.dart';
import 'tables.dart';

// Generated file. Create it with: dart run build_runner build
part 'app_database.g.dart';

@DriftDatabase(tables: [Categories, Expenses, Incomes, MonthlyBudgets, AppSettings])
class AppDatabase extends _$AppDatabase {
  /// Pass an executor in tests (e.g. an in-memory database).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'duit'));

  /// Increase this and add a step in onUpgrade when you change the tables.
  ///   1: first release
  ///   2: AppSettings.potStart (start a new overall budget)
  ///   3: Incomes table
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await batch((b) {
            b.insertAll(
              categories,
              defaultCategories
                  .map((c) => CategoriesCompanion.insert(
                        id: c.id,
                        name: c.name,
                        iconKey: c.iconKey,
                        colorValue: c.colorValue,
                        sortOrder: Value(c.sortOrder),
                      ))
                  .toList(),
            );
          });
        },
        onUpgrade: (m, from, to) async {
          // Version 2 added the start day of the current overall budget.
          if (from < 2) {
            await m.addColumn(appSettings, appSettings.potStart);
          }
          if (from < 3) {
            await m.createTable(incomes);
            await m.createIndex(Index('incomes_day', 'CREATE INDEX IF NOT EXISTS incomes_day ON incomes (day)'));
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
