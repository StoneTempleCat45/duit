import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/today_provider.dart';
import '../../data/providers.dart';
import '../../domain/budget_math.dart';
import '../../domain/models.dart';

/// Overall budget settings. Null means first-run setup is still needed.
final settingsProvider = StreamProvider<BudgetSettings?>(
  (ref) => ref.watch(budgetRepositoryProvider).watchSettings(),
);

final _trackingStartProvider = Provider<DateTime?>(
  (ref) => ref.watch(settingsProvider.select((s) => s.value?.trackingStart)),
);

final _potStartProvider = Provider<DateTime?>(
  (ref) => ref.watch(settingsProvider.select((s) => s.value?.potStart)),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

/// Categories by id, for quick lookups when drawing expense rows.
final categoryMapProvider = Provider<Map<String, Category>>((ref) {
  final list = ref.watch(categoriesProvider).value ?? const <Category>[];
  return {for (final c in list) c.id: c};
});

final currentMonthKeyProvider = Provider<String>((ref) => monthKey(ref.watch(todayProvider)));

/// The date range of the current monthly budget.
final periodProvider = Provider<BudgetPeriod?>((ref) {
  final start = ref.watch(_trackingStartProvider);
  if (start == null) return null;
  return periodFor(ref.watch(todayProvider), start);
});

/// This month's budget. When a new month starts, last month's amount is
/// carried over automatically.
final currentMonthBudgetProvider = StreamProvider<MonthlyBudget?>((ref) async* {
  final repo = ref.watch(budgetRepositoryProvider);
  final month = ref.watch(currentMonthKeyProvider);
  await repo.ensureMonth(month);
  yield* repo.watchMonth(month);
});

final periodExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final period = ref.watch(periodProvider);
  if (period == null) return Stream.value(const <Expense>[]);
  return ref.watch(expenseRepositoryProvider).watchBetween(period.start, period.end);
});

/// Total spent since the current overall budget started.
final overallSpentProvider = StreamProvider<int>((ref) {
  final start = ref.watch(_potStartProvider);
  if (start == null) return Stream.value(0);
  return ref.watch(expenseRepositoryProvider).watchTotalSince(start);
});

final allExpensesProvider = StreamProvider<List<Expense>>(
  (ref) => ref.watch(expenseRepositoryProvider).watchAll(),
);

/// Total income since the current overall budget started (it tops it up).
final overallIncomeProvider = StreamProvider<int>((ref) {
  final start = ref.watch(_potStartProvider);
  if (start == null) return Stream.value(0);
  return ref.watch(incomeRepositoryProvider).watchTotalSince(start);
});

final allIncomesProvider = StreamProvider<List<Income>>(
  (ref) => ref.watch(incomeRepositoryProvider).watchAll(),
);

/// Income received in the current monthly period.
final periodIncomesProvider = StreamProvider<List<Income>>((ref) {
  final period = ref.watch(periodProvider);
  if (period == null) return Stream.value(const <Income>[]);
  return ref.watch(incomeRepositoryProvider).watchBetween(period.start, period.end);
});

/// Everything the dashboard needs, in one object.
/// Data is null when this month has no budget set.
final budgetSummaryProvider = Provider<AsyncValue<BudgetSummary?>>((ref) {
  final settings = ref.watch(settingsProvider);
  final budget = ref.watch(currentMonthBudgetProvider);
  final expenses = ref.watch(periodExpensesProvider);
  final overallSpent = ref.watch(overallSpentProvider);
  final overallIncome = ref.watch(overallIncomeProvider);
  final period = ref.watch(periodProvider);
  final today = ref.watch(todayProvider);

  for (final AsyncValue<Object?> value in [settings, budget, expenses, overallSpent, overallIncome]) {
    if (value.hasError) {
      return AsyncError(value.error!, value.stackTrace ?? StackTrace.current);
    }
  }
  if (!settings.hasValue ||
      !budget.hasValue ||
      !expenses.hasValue ||
      !overallSpent.hasValue ||
      !overallIncome.hasValue) {
    return const AsyncLoading();
  }

  final s = settings.value;
  final b = budget.value;
  if (s == null || b == null || period == null) return const AsyncData(null);

  return AsyncData(summarize(
    today: today,
    period: period,
    monthBudgetCents: b.amountCents,
    periodExpenses: expenses.value!,
    overallCents: s.overallCents,
    overallSpentCents: overallSpent.value!,
    overallIncomeCents: overallIncome.value!,
  ));
});
