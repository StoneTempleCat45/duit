import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../domain/budget_math.dart';
import '../../domain/insights_math.dart';
import '../../domain/models.dart';
import '../budget/budget_providers.dart';
import 'charts.dart';

/// Charts for the current month: categories, daily spending and pace.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(budgetSummaryProvider);
    final expenses = ref.watch(periodExpensesProvider).value ?? const <Expense>[];
    final categories = ref.watch(categoryMapProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Something went wrong.\n$e', textAlign: TextAlign.center)),
          data: (summary) {
            if (summary == null) {
              return const Center(
                child: EmptyState(
                  icon: Icons.insights_rounded,
                  title: 'No budget this month',
                  message: 'Set a monthly budget on the Home tab to see your insights.',
                ),
              );
            }
            return _InsightsBody(summary: summary, expenses: expenses, categories: categories);
          },
        ),
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.summary, required this.expenses, required this.categories});

  final BudgetSummary summary;
  final List<Expense> expenses;
  final Map<String, Category> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final period = summary.period;
    final totalDays = period.totalDays;
    final elapsed = (daysBetween(period.start, summary.today) + 1).clamp(1, totalDays);
    final todayIndex = elapsed - 1;

    final daily = dailyTotals(expenses, period.start, totalDays);
    final running = runningTotals(daily.sublist(0, elapsed));
    final days = [for (var i = 0; i < totalDays; i++) DateTime(period.start.year, period.start.month, period.start.day + i)];
    final byCategory = categoryTotals(expenses);

    String? dayLabel(int i) {
      if (i < 0 || i >= totalDays) return null;
      final d = days[i];
      final isEdge = i == 0 || i == totalDays - 1;
      if (isEdge || i == todayIndex || (d.day % 5 == 0 && (i - todayIndex).abs() > 1 && i > 1 && i < totalDays - 2)) {
        return '${d.day}';
      }
      return null;
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Insights', style: theme.textTheme.headlineMedium),
          Text(
            '${monthName(summary.today)} · ${rangeLabel(period.start, period.end)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    if (expenses.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          header,
          const SizedBox(height: 24),
          const AppCard(
            child: EmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'Nothing to chart yet',
              message: 'Add a few expenses and your charts will appear here.',
            ),
          ),
        ],
      );
    }

    // Headline numbers.
    final average = summary.spentCents ~/ elapsed;
    var biggestIndex = 0;
    for (var i = 1; i < daily.length; i++) {
      if (daily[i] > daily[biggestIndex]) biggestIndex = i;
    }
    final top = byCategory.first;
    final topName = categories[top.categoryId]?.name ?? 'Others';
    final topPercent = summary.spentCents == 0 ? 0 : (top.cents * 100 / summary.spentCents).round();

    // Pace: what an even spread of the budget would have spent by today.
    final expectedByToday = summary.monthBudgetCents * elapsed ~/ totalDays;
    final paceDiff = expectedByToday - summary.spentCents;
    final underPace = paceDiff >= 0;

    var delay = 0;
    Widget stagger(Widget child) {
      delay += 70;
      return FadeSlideIn(delay: Duration(milliseconds: delay), child: child);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        header,
        const SizedBox(height: 18),
        stagger(Row(
          children: [
            Expanded(child: _StatPill(icon: Icons.av_timer_rounded, label: 'Average per day', value: formatMoney(average))),
            const SizedBox(width: 12),
            Expanded(
              child: _StatPill(
                icon: Icons.trending_up_rounded,
                label: 'Biggest day',
                value: formatMoney(daily[biggestIndex]),
                caption: DateFormat('EEE, d MMM').format(days[biggestIndex]),
              ),
            ),
          ],
        )),
        const SizedBox(height: 12),
        stagger(Row(
          children: [
            Expanded(
              child: _StatPill(
                icon: Icons.pie_chart_rounded,
                label: 'Top category',
                value: topName,
                caption: '$topPercent% of spending',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatPill(
                icon: Icons.receipt_rounded,
                label: 'Expenses',
                value: '${expenses.length}',
                caption: 'this month',
              ),
            ),
          ],
        )),
        const SizedBox(height: 16),
        stagger(AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(title: 'Where it went', subtitle: 'Tap a slice or a row for details'),
              const SizedBox(height: 8),
              CategoryDonut(totals: byCategory, categories: categories),
            ],
          ),
        )),
        const SizedBox(height: 16),
        stagger(AppCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(title: 'Daily spending', subtitle: 'Touch a bar to see the day'),
              const SizedBox(height: 18),
              SpendingBarChart(
                values: daily,
                days: days,
                highlightIndex: todayIndex,
                referenceCents: summary.monthBudgetCents ~/ totalDays,
                bottomLabel: dayLabel,
                barWidth: totalDays > 20 ? 6 : 10,
              ),
            ],
          ),
        )),
        const SizedBox(height: 16),
        stagger(AppCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _CardTitle(title: 'Spending pace', subtitle: 'Dashed line is an even pace to your budget'),
                  ),
                  _Chip(
                    text: underPace
                        ? '${formatMoney(paceDiff)} under'
                        : '${formatMoney(-paceDiff)} over',
                    color: underPace ? AppColors.success : AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              PaceLineChart(
                running: running,
                totalDays: totalDays,
                budgetCents: summary.monthBudgetCents,
                start: period.start,
                bottomLabel: dayLabel,
              ),
            ],
          ),
        )),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, required this.value, this.caption});

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientIcon(icon: icon),
          const SizedBox(height: 10),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (caption != null)
            Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
