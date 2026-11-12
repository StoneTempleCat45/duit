import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../domain/income_sources.dart';
import '../../domain/models.dart';

/// One expense row: category icon, note, category name, amount.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.category,
    this.onTap,
    this.today,
  });

  final Expense expense;
  final Category? category;
  final VoidCallback? onTap;

  /// When set, the day ("Today", "Mon, 3 Nov") is shown under the title.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final name = category?.name ?? 'Others';
    return _EntryRow(
      avatar: CategoryAvatar(category: category),
      title: _titleOr(expense.note, name),
      subtitle: today == null ? name : '$name · ${friendlyDay(expense.day, today!)}',
      amount: '-${formatMoney(expense.amountCents)}',
      onTap: onTap,
    );
  }
}

/// One income row, shown in green with a plus sign.
class IncomeTile extends StatelessWidget {
  const IncomeTile({super.key, required this.income, this.onTap, this.today});

  final Income income;
  final VoidCallback? onTap;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final source = incomeSourceMap[income.sourceId];
    final name = source?.name ?? 'Income';
    return _EntryRow(
      avatar: CategoryAvatar(category: source),
      title: _titleOr(income.note, name),
      subtitle: today == null ? 'Income · $name' : 'Income · ${friendlyDay(income.day, today!)}',
      amount: '+${formatMoney(income.amountCents)}',
      amountColor: AppColors.success,
      onTap: onTap,
    );
  }
}

String _titleOr(String? note, String fallback) => (note == null || note.isEmpty) ? fallback : note;

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.amountColor,
    this.onTap,
  });

  final Widget avatar;
  final String title;
  final String subtitle;
  final String amount;
  final Color? amountColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}
