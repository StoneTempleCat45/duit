import 'package:duit/core/money.dart';
import 'package:duit/domain/budget_math.dart';
import 'package:duit/domain/insights_math.dart';
import 'package:duit/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _e(int cents, DateTime day) => Expense(
      id: '$cents-$day',
      amountCents: cents,
      categoryId: 'food',
      day: day,
      createdAt: day,
      updatedAt: day,
    );

void main() {
  group('periodFor', () {
    test('first month starts on the tracking day', () {
      final p = periodFor(DateTime(2026, 11, 5), DateTime(2026, 11, 5));
      expect(p.start, DateTime(2026, 11, 5));
      expect(p.end, DateTime(2026, 11, 30));
      expect(p.totalDays, 26);
    });

    test('later months start on the 1st', () {
      final p = periodFor(DateTime(2026, 12, 10), DateTime(2026, 11, 5));
      expect(p.start, DateTime(2026, 12, 1));
      expect(p.end, DateTime(2026, 12, 31));
    });

    test('February in a leap year ends on the 29th', () {
      final p = periodFor(DateTime(2028, 2, 3), DateTime(2026, 11, 5));
      expect(p.end, DateTime(2028, 2, 29));
    });
  });

  group('summarize', () {
    test('monthly budget with RM500, overall RM1200', () {
      final today = DateTime(2026, 11, 10);
      final period = periodFor(today, DateTime(2026, 11, 5));
      final s = summarize(
        today: today,
        period: period,
        monthBudgetCents: 50000,
        periodExpenses: [_e(2000, DateTime(2026, 11, 10)), _e(8000, DateTime(2026, 11, 6))],
        overallCents: 120000,
        overallSpentCents: 10000,
      );
      expect(s.spentCents, 10000);
      expect(s.remainingCents, 40000);
      expect(s.usedPercent, 20);
      expect(s.todayCents, 2000);
      expect(s.daysLeft, 21); // 10..30 Nov
      // Left at the start of today: 500 - 80 = 420, over 21 days = 20.00
      expect(s.dailyAllowanceCents, 2000);
      expect(s.leftTodayCents, 0);
      expect(s.level, BudgetLevel.normal);
    });

    test('daily amount is limited by the overall budget', () {
      final today = DateTime(2027, 2, 1);
      final s = summarize(
        today: today,
        period: periodFor(today, DateTime(2026, 11, 5)),
        monthBudgetCents: 50000,
        periodExpenses: const [],
        overallCents: 120000,
        overallSpentCents: 112000, // only RM80 left in the pot
      );
      expect(s.limitedByOverall, isTrue);
      expect(s.dailyAllowanceCents, 8000 ~/ 28);
    });

    test('over budget gives a zero daily amount', () {
      final today = DateTime(2026, 11, 20);
      final s = summarize(
        today: today,
        period: periodFor(today, DateTime(2026, 11, 5)),
        monthBudgetCents: 50000,
        periodExpenses: [_e(52000, DateTime(2026, 11, 12))],
        overallCents: 120000,
        overallSpentCents: 52000,
      );
      expect(s.level, BudgetLevel.over);
      expect(s.dailyAllowanceCents, 0);
      expect(s.remainingCents, -2000);
    });

    test('80% is a warning', () {
      final today = DateTime(2026, 11, 20);
      final s = summarize(
        today: today,
        period: periodFor(today, DateTime(2026, 11, 5)),
        monthBudgetCents: 50000,
        periodExpenses: [_e(40000, DateTime(2026, 11, 12))],
        overallCents: 120000,
        overallSpentCents: 40000,
      );
      expect(s.level, BudgetLevel.warning);
    });
  });

  group('money', () {
    test('parses user input into cents', () {
      expect(parseMoneyToCents('12'), 1200);
      expect(parseMoneyToCents('12.5'), 1250);
      expect(parseMoneyToCents('12.05'), 1205);
      expect(parseMoneyToCents('1,200.00'), 120000);
      expect(parseMoneyToCents('.5'), 50);
      expect(parseMoneyToCents(''), isNull);
      expect(parseMoneyToCents('.'), isNull);
      expect(parseMoneyToCents('abc'), isNull);
      expect(parseMoneyToCents('1.234'), isNull);
    });

    test('formats cents', () {
      expect(formatMoney(125050), 'RM 1,250.50');
      expect(formatMoney(50000, compact: true), 'RM 500');
      expect(formatMoney(-2000), '-RM 20.00');
    });

    test('validates amounts', () {
      expect(validateAmount('0'), isNotNull);
      expect(validateAmount(''), isNotNull);
      expect(validateAmount('8.50'), isNull);
    });
  });

  group('insights', () {
    final start = DateTime(2026, 11, 5);
    final expenses = [
      _e(1000, DateTime(2026, 11, 5)),
      _e(500, DateTime(2026, 11, 5)),
      _e(2000, DateTime(2026, 11, 7)),
      _e(9999, DateTime(2026, 10, 30)), // before the range, ignored by dailyTotals
    ];

    test('daily totals by day offset', () {
      expect(dailyTotals(expenses, start, 4), [1500, 0, 2000, 0]);
    });

    test('running totals', () {
      expect(runningTotals([1500, 0, 2000, 0]), [1500, 1500, 3500, 3500]);
    });

    test('category totals, biggest first', () {
      final list = categoryTotals(expenses.take(3));
      expect(list.single.categoryId, 'food');
      expect(list.single.cents, 3500);
      expect(list.single.count, 3);
    });
  });

  test('income tops up the overall budget', () {
    final today = DateTime(2027, 2, 1);
    final s = summarize(
      today: today,
      period: periodFor(today, DateTime(2026, 11, 5)),
      monthBudgetCents: 50000,
      periodExpenses: const [],
      overallCents: 120000,
      overallSpentCents: 112000, // RM80 left before income
      overallIncomeCents: 30000, // +RM300 received
    );
    expect(s.overallTotalCents, 150000);
    expect(s.overallRemainingCents, 38000);
    expect(s.dailyAllowanceCents, 38000 ~/ 28);
  });
}

