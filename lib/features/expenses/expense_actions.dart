import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models.dart';

/// Deletes an expense and shows a snackbar with an Undo button.
Future<void> deleteExpenseWithUndo({
  required ExpenseRepository repo,
  required ScaffoldMessengerState messenger,
  required Expense expense,
  VoidCallback? onUndo,
}) async {
  await repo.delete(expense.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('Deleted ${formatMoney(expense.amountCents)} expense'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await repo.save(expense);
          onUndo?.call();
        },
      ),
    ));
}

/// Deletes an income entry and shows a snackbar with an Undo button.
Future<void> deleteIncomeWithUndo({
  required IncomeRepository repo,
  required ScaffoldMessengerState messenger,
  required Income income,
  VoidCallback? onUndo,
}) async {
  await repo.delete(income.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('Deleted ${formatMoney(income.amountCents)} income'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await repo.save(income);
          onUndo?.call();
        },
      ),
    ));
}

/// Asks the user to confirm a delete. Returns true when they tap Delete.
Future<bool> confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this expense?'),
      content: const Text('You can undo this right after.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  return result ?? false;
}
