import 'dart:math' as math;

import '../core/dates.dart';
import 'models.dart';

enum BudgetLevel { normal, warning, over }

/// The date range the current monthly budget covers (both days inclusive).
class BudgetPeriod {
  const BudgetPeriod(this.start, this.end);

  final DateTime start;
  final DateTime end;

  int get totalDays => daysBetween(start, end) + 1;

  @override
  bool operator ==(Object other) =>
      other is BudgetPeriod && isSameDay(other.start, start) && isSameDay(other.end, end);

  @override
  int get hashCode => Object.hash(dayKey(start), dayKey(end));
}

/// The first month runs from the tracking start day to the end of that month.
/// Every later month runs from the 1st to the last day.
BudgetPeriod periodFor(DateTime today, DateTime trackingStart) {
  final t = dateOnly(today);
  final monthStart = DateTime(t.year, t.month, 1);
  final ts = dateOnly(trackingStart);
  var start = ts.isAfter(monthStart) ? ts : monthStart;
  if (start.isAfter(t)) start = t; // phone clock moved backwards
  return BudgetPeriod(start, lastDayOfMonth(t));
}

class BudgetSummary {
  const BudgetSummary({
    required this.period,
    required this.today,
    required this.monthBudgetCents,
    required this.spentCents,
    required this.todayCents,
    required this.todayCount,
    required this.overallCents,
    required this.overallSpentCents,
    required this.overallIncomeCents,
    required this.daysLeft,
    required this.dailyAllowanceCents,
  });

  final BudgetPeriod period;
  final DateTime today;
  final int monthBudgetCents;
  final int spentCents;
  final int todayCents;
  final int todayCount;
  final int overallCents;
  final int overallSpentCents;

  /// Money added since the overall budget started. It tops up the budget.
  final int overallIncomeCents;

  /// Days left in the period, counting today.
  final int daysLeft;

  /// How much can be spent per day, from today to the end of the month,
  /// without going over the monthly budget or the overall budget.
  final int dailyAllowanceCents;

  int get remainingCents => monthBudgetCents - spentCents;
  /// The overall budget plus any income added to it.
  int get overallTotalCents => overallCents + overallIncomeCents;
  int get overallRemainingCents => overallTotalCents - overallSpentCents;

  /// What is left of today's daily amount (negative when over).
  int get leftTodayCents => dailyAllowanceCents - todayCents;

  double get usedRatio => monthBudgetCents <= 0 ? 0 : spentCents / monthBudgetCents;
  int get usedPercent => (usedRatio * 100).round();

  double get overallUsedRatio => overallTotalCents <= 0 ? 0 : overallSpentCents / overallTotalCents;

  /// True when the overall pot, not the monthly budget, sets the daily amount.
  bool get limitedByOverall => overallRemainingCents < remainingCents;

  BudgetLevel get level {
    if (usedRatio >= 1) return BudgetLevel.over;
    if (usedRatio >= 0.8) return BudgetLevel.warning;
    return BudgetLevel.normal;
  }
}

BudgetSummary summarize({
  required DateTime today,
  required BudgetPeriod period,
  required int monthBudgetCents,
  required List<Expense> periodExpenses,
  required int overallCents,
  required int overallSpentCents,
  int overallIncomeCents = 0,
}) {
  final t = dateOnly(today);
  var spent = 0;
  var todaySpent = 0;
  var todayCount = 0;
  for (final e in periodExpenses) {
    spent += e.amountCents;
    if (isSameDay(e.day, t)) {
      todaySpent += e.amountCents;
      todayCount++;
    }
  }

  final daysLeft = math.max(1, daysBetween(t, period.end) + 1);

  // Use what was left at the start of today, so the daily amount stays the
  // same all day instead of shrinking with every purchase.
  final monthLeftBeforeToday = monthBudgetCents - (spent - todaySpent);
  final overallLeftBeforeToday = overallCents + overallIncomeCents - overallSpentCents + todaySpent;
  final spendable = math.min(monthLeftBeforeToday, overallLeftBeforeToday);
  final allowance = spendable <= 0 ? 0 : spendable ~/ daysLeft;

  return BudgetSummary(
    period: period,
    today: t,
    monthBudgetCents: monthBudgetCents,
    spentCents: spent,
    todayCents: todaySpent,
    todayCount: todayCount,
    overallCents: overallCents,
    overallSpentCents: overallSpentCents,
    overallIncomeCents: overallIncomeCents,
    daysLeft: daysLeft,
    dailyAllowanceCents: allowance,
  );
}
