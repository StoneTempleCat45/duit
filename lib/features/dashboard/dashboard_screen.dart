import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../domain/budget_math.dart';
import '../../domain/insights_math.dart';
import '../../domain/models.dart';
import '../budget/budget_providers.dart';
import '../expenses/add_edit_expense_screen.dart';
import '../expenses/expense_tile.dart';
import '../insights/charts.dart';
import '../settings/budget_settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.onSeeAll});

  /// Switches to the History tab.
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(budgetSummaryProvider);
    final monthBudget = ref.watch(currentMonthBudgetProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Something went wrong.\n$e', textAlign: TextAlign.center)),
          data: (summary) {
            var delay = 0;
            Widget stagger(Widget child) {
              delay += 70;
              return FadeSlideIn(delay: Duration(milliseconds: delay), child: child);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _Header(summary: summary),
                const SizedBox(height: 16),
                if (monthBudget != null && monthBudget.carriedOver) ...[
                  _NewMonthBanner(budget: monthBudget),
                  const SizedBox(height: 16),
                ],
                if (summary == null)
                  const _NoMonthBudget()
                else ...[
                  stagger(_BudgetHero(summary: summary)),
                  const SizedBox(height: 14),
                  stagger(_StatRow(summary: summary)),
                  const SizedBox(height: 14),
                  stagger(_WeekCard(today: summary.today)),
                  const SizedBox(height: 14),
                  stagger(_OverallCard(summary: summary)),
                  const SizedBox(height: 24),
                  stagger(_RecentSection(onSeeAll: onSeeAll)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

void _openSettings(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BudgetSettingsScreen()));
}

String _greeting(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final BudgetSummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(DateTime.now()),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Duit'),
                  TextSpan(text: '.', style: TextStyle(color: theme.colorScheme.primary)),
                ]),
                style: theme.textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        if (s != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${s.daysLeft} ${s.daysLeft == 1 ? 'day' : 'days'} left',
              style: theme.textTheme.labelLarge,
            ),
          ),
        const SizedBox(width: 8),
        Pressable(
          onTap: () => _openSettings(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tune_rounded, color: theme.colorScheme.onSurface, semanticLabel: 'Budget settings'),
          ),
        ),
      ],
    );
  }
}

/// The big gradient card. Tap it to switch between "left" and "spent".
class _BudgetHero extends StatefulWidget {
  const _BudgetHero({required this.summary});

  final BudgetSummary summary;

  @override
  State<_BudgetHero> createState() => _BudgetHeroState();
}

class _BudgetHeroState extends State<_BudgetHero> {
  bool _showSpent = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.summary;
    final colors = AppGradients.brand(theme.brightness);
    final over = s.remainingCents < 0;

    final ringColors = switch (s.level) {
      BudgetLevel.normal => const [AppColors.highlight, Color(0xFFFFE08A)],
      BudgetLevel.warning => const [AppColors.warning, AppColors.highlight],
      BudgetLevel.over => const [AppColors.dangerDark, AppColors.warning],
    };

    final String label;
    final int amount;
    if (_showSpent) {
      label = 'Spent this month';
      amount = s.spentCents;
    } else {
      label = over ? 'Over budget by' : 'Left this month';
      amount = s.remainingCents.abs();
    }

    return Semantics(
      button: true,
      label: '$label ${formatMoney(amount)}. ${s.usedPercent}% of budget used. Tap to switch.',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => setState(() => _showSpent = !_showSpent),
        scale: 0.98,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: colors.last.withValues(alpha: 0.38), blurRadius: 34, offset: const Offset(0, 16)),
            ],
          ),
          child: Stack(
            children: [
              // Decorative glows.
              Positioned(
                right: -60,
                top: -70,
                child: _Glow(size: 200, color: AppColors.highlight.withValues(alpha: 0.30)),
              ),
              Positioned(
                left: -50,
                bottom: -80,
                child: _Glow(size: 180, color: Colors.white.withValues(alpha: 0.14)),
              ),
              // Glossy highlight across the top.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.20), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Eyebrow(label, key: ValueKey(label), color: Colors.white.withValues(alpha: 0.85)),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: AnimatedMoney(
                                  amount,
                                  style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontSize: 38),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.touch_app_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showSpent ? 'Tap to see what is left' : 'Tap to see what you spent',
                                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ProgressRing(
                          value: s.usedRatio,
                          colors: ringColors,
                          trackColor: Colors.white.withValues(alpha: 0.18),
                          size: 96,
                          stroke: 11,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${s.usedPercent}%',
                                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                              ),
                              Text(
                                'used',
                                style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _GlassChip(label: 'Spent', value: formatMoney(s.spentCents))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GlassChip(label: 'Budget', value: formatMoney(s.monthBudgetCents, compact: true)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Frosted pill on the hero card.
class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leftToday = summary.leftTodayCents;
    final todayCaption = leftToday >= 0
        ? '${formatMoney(leftToday)} left today'
        : '${formatMoney(-leftToday)} over today';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.bolt_rounded,
              label: 'Safe per day',
              value: summary.dailyAllowanceCents,
              caption: todayCaption,
              captionColor: leftToday >= 0 ? AppColors.success : theme.colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.today_rounded,
              label: 'Spent today',
              value: summary.todayCents,
              caption: summary.todayCount == 0
                  ? 'Nothing yet'
                  : '${summary.todayCount} ${summary.todayCount == 1 ? 'expense' : 'expenses'}',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.captionColor,
  });

  final IconData icon;
  final String label;
  final int value;
  final String caption;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIcon(icon: icon, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedMoney(value, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: captionColor ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The last 7 days as a small interactive bar chart.
class _WeekCard extends ConsumerWidget {
  const _WeekCard({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(allExpensesProvider).value ?? const <Expense>[];
    final start = DateTime(today.year, today.month, today.day - 6);
    final days = [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
    final values = dailyTotals(all, start, 7);
    final total = values.fold<int>(0, (a, b) => a + b);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Last 7 days', style: theme.textTheme.titleLarge)),
              AnimatedMoney(total, style: theme.textTheme.titleSmall),
            ],
          ),
          Text(
            'Touch a bar for details',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SpendingBarChart(
            values: values,
            days: days,
            highlightIndex: 6,
            height: 130,
            barWidth: 22,
            bottomLabel: (i) => (i >= 0 && i < 7) ? DateFormat('E').format(days[i]).substring(0, 2) : null,
          ),
        ],
      ),
    );
  }
}

/// The overall budget and how much of it is left.
class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = summary.overallRemainingCents;

    final notes = <String>[
      if (summary.overallIncomeCents > 0)
        'Includes ${formatMoney(summary.overallIncomeCents)} of income you added.',
      if (left <= 0)
        'Your overall budget is used up. Add income with the + button.'
      else if (summary.limitedByOverall)
        'Your daily amount is based on what is left in your overall budget.',
    ];
    final note = notes.isEmpty ? null : notes.join(' ');

    return AppCard(
      onTap: () => _openSettings(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(icon: Icons.account_balance_wallet_rounded, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text('Overall budget', style: theme.textTheme.titleSmall)),
              Text(
                'of ${formatMoney(summary.overallTotalCents, compact: true)}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedMoney(left, style: theme.textTheme.titleLarge?.copyWith(color: left < 0 ? scheme.error : null)),
              const SizedBox(width: 6),
              Text('left', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBar(
            value: summary.overallUsedRatio,
            height: 8,
            color: left <= 0 ? scheme.error : scheme.primary,
            trackColor: scheme.onSurface.withValues(alpha: 0.07),
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(note, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expenses = ref.watch(periodExpensesProvider).value ?? const <Expense>[];
    final incomes = ref.watch(periodIncomesProvider).value ?? const <Income>[];
    final categories = ref.watch(categoryMapProvider);
    final today = ref.watch(budgetSummaryProvider).value?.today ?? dateOnly(DateTime.now());

    // Newest five entries, spending and income mixed.
    final recent = <({DateTime day, DateTime createdAt, Expense? expense, Income? income})>[
      for (final e in expenses) (day: e.day, createdAt: e.createdAt, expense: e, income: null),
      for (final i in incomes) (day: i.day, createdAt: i.createdAt, expense: null, income: i),
    ]..sort((a, b) {
        final byDay = b.day.compareTo(a.day);
        return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
      });
    final shown = recent.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Recent', style: theme.textTheme.titleLarge)),
            if (recent.isNotEmpty) TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: shown.isEmpty
              ? const AppCard(
                  key: ValueKey('empty'),
                  child: EmptyState(
                    icon: Icons.savings_rounded,
                    title: 'No spending yet this month',
                    message: 'Tap the + button to log your first expense.',
                  ),
                )
              : AppCard(
                  key: const ValueKey('list'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      for (final entry in shown)
                        if (entry.income != null)
                          IncomeTile(
                            income: entry.income!,
                            today: today,
                            onTap: () => openAddExpense(context, income: entry.income),
                          )
                        else
                          ExpenseTile(
                            expense: entry.expense!,
                            category: categories[entry.expense!.categoryId],
                            today: today,
                            onTap: () => openAddExpense(context, expense: entry.expense),
                          ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _NewMonthBanner extends ConsumerWidget {
  const _NewMonthBanner({required this.budget});

  final MonthlyBudget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = monthName(parseDayKey('${budget.month}-01'));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.highlight.withValues(alpha: 0.35), AppColors.warning.withValues(alpha: 0.18)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to $month', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Your monthly budget of ${formatMoney(budget.amountCents, compact: true)} carried over from last month.',
            style: theme.textTheme.bodyMedium,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => _openSettings(context), child: const Text('Change')),
              TextButton(
                onPressed: () => ref.read(budgetRepositoryProvider).acknowledgeCarryOver(budget.month),
                child: const Text('Got it'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoMonthBudget extends StatelessWidget {
  const _NoMonthBudget();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const EmptyState(
            icon: Icons.account_balance_wallet_rounded,
            title: 'No budget for this month',
            message: 'Set a monthly budget to see what you can spend each day.',
          ),
          GradientButton(label: 'Set monthly budget', onPressed: () => _openSettings(context)),
        ],
      ),
    );
  }
}
