import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../domain/insights_math.dart';
import '../../domain/models.dart';

const _chartDuration = Duration(milliseconds: 450);

TextStyle _axisStyle(BuildContext context) => Theme.of(context).textTheme.labelSmall!.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

/// Dark bubble used for every chart tooltip.
Color _tooltipColor(BuildContext context) => Theme.of(context).colorScheme.inverseSurface;
Color _tooltipText(BuildContext context) => Theme.of(context).colorScheme.onInverseSurface;

/// Bar chart of spending per day. Touch a bar to see the amount and date.
class SpendingBarChart extends StatefulWidget {
  const SpendingBarChart({
    super.key,
    required this.values,
    required this.days,
    required this.bottomLabel,
    this.highlightIndex,
    this.referenceCents,
    this.height = 180,
    this.barWidth = 8,
  });

  /// Cents per day.
  final List<int> values;
  final List<DateTime> days;

  /// Label under bar [index], or null for none.
  final String? Function(int index) bottomLabel;

  /// Usually today.
  final int? highlightIndex;

  /// Draws a dashed line, e.g. the daily budget. Bars above it turn orange.
  final int? referenceCents;
  final double height;
  final double barWidth;

  @override
  State<SpendingBarChart> createState() => _SpendingBarChartState();
}

class _SpendingBarChartState extends State<SpendingBarChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = AppGradients.bars(context);
    final faded = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: brand.colors.map((c) => c.withValues(alpha: 0.38)).toList(),
    );
    const warning = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFFFF9F43), Color(0xFFFF6B7A)],
    );

    final reference = widget.referenceCents;
    final maxValue = [...widget.values, reference ?? 0].fold<int>(0, math.max);
    final maxY = maxValue == 0 ? 10.0 : maxValue / 100 * 1.22;

    return SizedBox(
      height: widget.height,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          alignment: BarChartAlignment.spaceBetween,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final label = widget.bottomLabel(value.toInt());
                  if (label == null) return const SizedBox.shrink();
                  final isHighlight = value.toInt() == widget.highlightIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: _axisStyle(context).copyWith(color: isHighlight ? scheme.primary : null),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (reference != null && reference > 0)
                HorizontalLine(
                  y: reference / 100,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  strokeWidth: 1.4,
                  dashArray: const [5, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(bottom: 4),
                    style: _axisStyle(context),
                    labelResolver: (_) => '${formatMoney(reference)}/day',
                  ),
                ),
            ],
          ),
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              final index = response?.spot?.touchedBarGroupIndex;
              if (!event.isInterestedForInteractions || index == null) {
                if (_touched != null) setState(() => _touched = null);
                return;
              }
              if (index != _touched) {
                HapticFeedback.selectionClick();
                setState(() => _touched = index);
              }
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _tooltipColor(context),
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tooltipMargin: 8,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${formatMoney(widget.values[group.x])}\n',
                TextStyle(color: _tooltipText(context), fontWeight: FontWeight.w700, fontSize: 13),
                children: [
                  TextSpan(
                    text: DateFormat('EEE, d MMM').format(widget.days[group.x]),
                    style: TextStyle(
                      color: _tooltipText(context).withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < widget.values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: widget.values[i] / 100,
                    width: widget.barWidth,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(widget.barWidth / 2),
                      bottom: const Radius.circular(2),
                    ),
                    gradient: (reference != null && reference > 0 && widget.values[i] > reference)
                        ? warning
                        : (i == widget.highlightIndex || i == _touched)
                            ? brand
                            : faded,
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: scheme.onSurface.withValues(alpha: 0.04),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: _chartDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

/// Donut of spending by category with a tappable legend.
class CategoryDonut extends StatefulWidget {
  const CategoryDonut({super.key, required this.totals, required this.categories});

  final List<CategoryTotal> totals;
  final Map<String, Category> categories;

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  int? _selected;

  void _select(int? index) {
    HapticFeedback.selectionClick();
    setState(() => _selected = (index == _selected) ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totals = widget.totals;
    final total = totals.fold<int>(0, (sum, t) => sum + t.cents);
    final selected = (_selected != null && _selected! < totals.length) ? totals[_selected!] : null;
    final selectedCategory = selected == null ? null : widget.categories[selected.categoryId];

    Color colorOf(CategoryTotal t) => Color(widget.categories[t.categoryId]?.colorValue ?? 0xFF7A8296);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 3,
                  centerSpaceRadius: 70,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final index = response?.touchedSection?.touchedSectionIndex ?? -1;
                      _select(index >= 0 ? index : null);
                    },
                  ),
                  sections: [
                    for (var i = 0; i < totals.length; i++)
                      PieChartSectionData(
                        value: totals[i].cents.toDouble(),
                        color: (_selected == null || _selected == i)
                            ? colorOf(totals[i])
                            : colorOf(totals[i]).withValues(alpha: 0.3),
                        radius: _selected == i ? 36 : 28,
                        showTitle: false,
                      ),
                  ],
                ),
                duration: _chartDuration,
                curve: Curves.easeOutCubic,
              ),
              IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(_selected),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCategory?.name ?? 'Total spent',
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatMoney(selected?.cents ?? total),
                        style: theme.textTheme.titleLarge,
                      ),
                      if (selected != null)
                        Text(
                          '${(selected.cents * 100 / total).round()}% · ${selected.count} '
                          '${selected.count == 1 ? 'expense' : 'expenses'}',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < totals.length; i++)
          Pressable(
            onTap: () => _select(i),
            haptic: false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: _selected == i ? colorOf(totals[i]).withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CategoryAvatar(category: widget.categories[totals[i].categoryId], size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.categories[totals[i].categoryId]?.name ?? 'Others',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        AnimatedBar(
                          value: total == 0 ? 0 : totals[i].cents / total,
                          color: colorOf(totals[i]),
                          trackColor: scheme.onSurface.withValues(alpha: 0.06),
                          height: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatMoney(totals[i].cents), style: theme.textTheme.titleSmall),
                      Text(
                        '${total == 0 ? 0 : (totals[i].cents * 100 / total).round()}%',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Running total of spending against an even pace to the budget.
class PaceLineChart extends StatelessWidget {
  const PaceLineChart({
    super.key,
    required this.running,
    required this.totalDays,
    required this.budgetCents,
    required this.start,
    required this.bottomLabel,
    this.height = 190,
  });

  /// Running total in cents for each day so far (index 0 = first day).
  final List<int> running;
  final int totalDays;
  final int budgetCents;
  final DateTime start;
  final String? Function(int index) bottomLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = AppGradients.bars(context);
    final last = running.isEmpty ? 0 : running.last;
    final maxY = math.max(math.max(budgetCents, last), 100) / 100 * 1.15;
    final maxX = math.max(totalDays - 1, 1).toDouble();

    final actual = LineChartBarData(
      spots: [for (var i = 0; i < running.length; i++) FlSpot(i.toDouble(), running[i] / 100)],
      isCurved: true,
      curveSmoothness: 0.22,
      preventCurveOverShooting: true,
      barWidth: 3.5,
      isStrokeCapRound: true,
      gradient: LinearGradient(colors: brand.colors),
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, bar) => spot.x == running.length - 1,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 5,
          color: scheme.surface,
          strokeWidth: 3,
          strokeColor: brand.colors.last,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [brand.colors.last.withValues(alpha: 0.28), brand.colors.first.withValues(alpha: 0.0)],
        ),
      ),
    );

    final pace = LineChartBarData(
      spots: [FlSpot(0, budgetCents / totalDays / 100), FlSpot(maxX, budgetCents / 100)],
      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      barWidth: 1.5,
      dashArray: const [6, 5],
      dotData: const FlDotData(show: false),
    );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
          lineBarsData: [actual, pace],
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.onSurface.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) return const SizedBox.shrink();
                  final label = bottomLabel(value.toInt());
                  if (label == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: _axisStyle(context)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => _tooltipColor(context),
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => spots.map((s) {
                if (s.barIndex != 0) return null;
                final day = DateTime(start.year, start.month, start.day + s.x.toInt());
                return LineTooltipItem(
                  '${formatMoney((s.y * 100).round())}\n',
                  TextStyle(color: _tooltipText(context), fontWeight: FontWeight.w700, fontSize: 13),
                  children: [
                    TextSpan(
                      text: 'by ${DateFormat('d MMM').format(day)}',
                      style: TextStyle(
                        color: _tooltipText(context).withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        duration: _chartDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
