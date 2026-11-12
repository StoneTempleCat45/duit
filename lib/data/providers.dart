import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/app_database.dart';
import 'repositories/drift_repositories.dart';
import 'repositories/repositories.dart';

/// One database for the whole app. Tests can override this provider with an
/// in-memory database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => DriftExpenseRepository(ref.watch(databaseProvider)),
);

final incomeRepositoryProvider = Provider<IncomeRepository>(
  (ref) => DriftIncomeRepository(ref.watch(databaseProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => DriftCategoryRepository(ref.watch(databaseProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => DriftBudgetRepository(ref.watch(databaseProvider)),
);
