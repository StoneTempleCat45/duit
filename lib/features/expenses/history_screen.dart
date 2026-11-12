import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/today_provider.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../budget/budget_providers.dart';
import 'add_edit_expense_screen.dart';
import 'expense_actions.dart';
import 'expense_tile.dart';

/// An expense or an income, so both can share one list.
class _Entry {
  _Entry.expense(Expense e)
      : expense = e,
        income = null,
        id = 'e_${e.id}',
        day = e.day,
        createdAt = e.createdAt;

  _Entry.income(Income i)
      : expense = null,
        income = i,
        id = 'i_${i.id}',
        day = i.day,
        createdAt = i.createdAt;

  final Expense? expense;
  final Income? income;
  final String id;
  final DateTime day;
  final DateTime createdAt;

  bool get isIncome => income != null;
  int get cents => expense?.amountCents ?? income!.amountCents;
}

class _DayGroup {
  _DayGroup(this.day);

  final DateTime day;
  final List<_Entry> entries = [];

  int get spent => entries.where((e) => !e.isIncome).fold(0, (sum, e) => sum + e.cents);
  int get received => entries.where((e) => e.isIncome).fold(0, (sum, e) => sum + e.cents);
}

/// Spending and income grouped by day, newest first. Swipe left to delete.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// Hidden immediately on swipe, before the database confirms the delete.
  final Set<String> _hidden = {};

  Future<void> _onDismissed(_Entry entry) async {
    setState(() => _hidden.add(entry.id));
    final messenger = ScaffoldMessenger.of(context);
    void undo() {
      if (mounted) setState(() => _hidden.remove(entry.id));
    }

    final expense = entry.expense;
    final income = entry.income;
    if (expense != null) {
      await deleteExpenseWithUndo(
        repo: ref.read(expenseRepositoryProvider),
        messenger: messenger,
        expense: expense,
        onUndo: undo,
      );
    } else if (income != null) {
      await deleteIncomeWithUndo(
        repo: ref.read(incomeRepositoryProvider),
        messenger: messenger,
        income: income,
        onUndo: undo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(allExpensesProvider);
    final incomesAsync = ref.watch(allIncomesProvider);
    final categories = ref.watch(categoryMapProvider);
    final today = ref.watch(todayProvider);

    Widget body;
    if (expensesAsync.hasError || incomesAsync.hasError) {
      body = Center(
        child: Text(
          'Could not load your history.\n${expensesAsync.error ?? incomesAsync.error}',
          textAlign: TextAlign.center,
        ),
      );
    } else if (!expensesAsync.hasValue || !incomesAsync.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final entries = <_Entry>[
        for (final e in expensesAsync.value!) _Entry.expense(e),
        for (final i in incomesAsync.value!) _Entry.income(i),
      ].where((e) => !_hidden.contains(e.id)).toList()
        ..sort((a, b) {
          final byDay = b.day.compareTo(a.day);
          return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
        });

      final groups = <_DayGroup>[];
      for (final e in entries) {
        if (groups.isEmpty || !isSameDay(groups.last.day, e.day)) groups.add(_DayGroup(e.day));
        groups.last.entries.add(e);
      }

      final header = Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text('History', style: theme.textTheme.headlineMedium)),
            if (entries.isNotEmpty)
              Text(
                '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      );

      if (entries.isEmpty) {
        body = ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            header,
            const SizedBox(height: 24),
            const AppCard(
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Nothing here yet',
                message: 'Tap the + button to add an expense or income. It will show up here, grouped by day.',
              ),
            ),
          ],
        );
      } else {
        body = ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: groups.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return header;
            final group = groups[i - 1];
            return FadeSlideIn(
              delay: Duration(milliseconds: 40 * i.clamp(1, 8)),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                      child: Row(
                        children: [
                          Expanded(child: Eyebrow(friendlyDay(group.day, today))),
                          if (group.received > 0) ...[
                            Text(
                              '+${formatMoney(group.received)}',
                              style: theme.textTheme.labelMedium?.copyWith(color: AppColors.success),
                            ),
                            if (group.spent > 0) const SizedBox(width: 10),
                          ],
                          if (group.spent > 0)
                            Text(
                              '-${formatMoney(group.spent)}',
                              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        children: [
                          for (final entry in group.entries)
                            Dismissible(
                              key: ValueKey(entry.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _onDismissed(entry),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                              ),
                              child: entry.isIncome
                                  ? IncomeTile(
                                      income: entry.income!,
                                      onTap: () => openAddExpense(context, income: entry.income),
                                    )
                                  : ExpenseTile(
                                      expense: entry.expense!,
                                      category: categories[entry.expense!.categoryId],
                                      onTap: () => openAddExpense(context, expense: entry.expense),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: body),
    );
  }
}
