import '../../domain/models.dart';

// The app only talks to these interfaces. Today they are backed by Drift
// (see the drift_*.dart files). To add cloud sync later, write another
// implementation or wrap these ones - the screens stay the same.

abstract interface class ExpenseRepository {
  /// Expenses from [from] to [to] (inclusive days), newest first.
  Stream<List<Expense>> watchBetween(DateTime from, DateTime to);

  /// Every expense, newest first.
  Stream<List<Expense>> watchAll();

  /// Sum of all expenses on or after [from], in cents.
  Stream<int> watchTotalSince(DateTime from);

  Future<Expense?> getById(String id);

  /// Inserts a new expense or replaces an existing one with the same id.
  Future<void> save(Expense expense);

  Future<void> delete(String id);
}

abstract interface class IncomeRepository {
  /// Every income, newest first.
  Stream<List<Income>> watchAll();

  /// Incomes from [from] to [to] (inclusive days), newest first.
  Stream<List<Income>> watchBetween(DateTime from, DateTime to);

  /// Sum of all income on or after [from], in cents.
  Stream<int> watchTotalSince(DateTime from);

  Future<void> save(Income income);

  Future<void> delete(String id);
}

abstract interface class CategoryRepository {
  Stream<List<Category>> watchAll();
}

abstract interface class BudgetRepository {
  /// Null until the first-run setup is finished.
  Stream<BudgetSettings?> watchSettings();

  Stream<MonthlyBudget?> watchMonth(String month);

  /// Saves the overall and first monthly budget, starting tracking today.
  Future<void> completeSetup({
    required int overallCents,
    required int monthlyCents,
    required DateTime today,
  });

  Future<void> updateOverall(int overallCents);

  /// Moves the tracking start back to [day] if [day] is earlier, so an entry
  /// dated before setup still counts in its month.
  Future<void> extendTrackingStart(DateTime day);

  /// Starts a fresh overall budget from [today]. Earlier spending no longer
  /// counts against it, but stays in the history.
  Future<void> startNewOverall({required int overallCents, required DateTime today});

  /// Removes every expense and budget. The app returns to first-run setup.
  Future<void> deleteAllData();

  Future<void> setMonthBudget(String month, int cents);

  /// Creates this month's budget by copying the latest earlier month,
  /// if it does not exist yet. Called when a new month starts.
  Future<void> ensureMonth(String month);

  /// Hides the "new month" banner.
  Future<void> acknowledgeCarryOver(String month);

  Future<void> markWarned(String month, {bool? warned80, bool? warned100});
}
