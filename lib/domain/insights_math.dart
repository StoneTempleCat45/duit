import '../core/dates.dart';
import 'models.dart';

class CategoryTotal {
  const CategoryTotal(this.categoryId, this.cents, this.count);

  final String categoryId;
  final int cents;
  final int count;
}

/// Spending per category, biggest first.
List<CategoryTotal> categoryTotals(Iterable<Expense> expenses) {
  final cents = <String, int>{};
  final counts = <String, int>{};
  for (final e in expenses) {
    cents[e.categoryId] = (cents[e.categoryId] ?? 0) + e.amountCents;
    counts[e.categoryId] = (counts[e.categoryId] ?? 0) + 1;
  }
  final list = [for (final id in cents.keys) CategoryTotal(id, cents[id]!, counts[id]!)];
  list.sort((a, b) => b.cents.compareTo(a.cents));
  return list;
}

/// Spending for each of [days] days starting at [start]. Index 0 is [start].
List<int> dailyTotals(Iterable<Expense> expenses, DateTime start, int days) {
  final totals = List<int>.filled(days, 0);
  for (final e in expenses) {
    final i = daysBetween(start, e.day);
    if (i >= 0 && i < days) totals[i] += e.amountCents;
  }
  return totals;
}

/// Running total of [daily]: each value is the sum up to and including that day.
List<int> runningTotals(List<int> daily) {
  var sum = 0;
  return [for (final d in daily) sum += d];
}
