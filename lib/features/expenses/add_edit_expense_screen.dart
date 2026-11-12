import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/today_provider.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../domain/income_sources.dart';
import '../../domain/models.dart';
import '../budget/budget_providers.dart';
import '../budget/budget_widgets.dart';
import 'expense_actions.dart';

/// Opens the add screen. Pass [expense] or [income] to edit one, or
/// [asIncome] to start on the Income tab.
Future<void> openAddExpense(
  BuildContext context, {
  Expense? expense,
  Income? income,
  bool asIncome = false,
}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => AddEditExpenseScreen(expense: expense, income: income, asIncome: asIncome),
  ));
}

/// Add or edit money going out (expense) or coming in (income).
class AddEditExpenseScreen extends ConsumerStatefulWidget {
  const AddEditExpenseScreen({super.key, this.expense, this.income, this.asIncome = false});

  final Expense? expense;
  final Income? income;
  final bool asIncome;

  @override
  ConsumerState<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends ConsumerState<AddEditExpenseScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late bool _isIncome;
  late String _categoryId;
  late String _sourceId;
  late DateTime _day;
  bool _saving = false;

  bool get _isEditing => widget.expense != null || widget.income != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    final i = widget.income;
    _isIncome = i != null || (e == null && widget.asIncome);
    final amount = e?.amountCents ?? i?.amountCents;
    _amountCtrl = TextEditingController(text: amount == null ? '' : centsToInput(amount));
    _noteCtrl = TextEditingController(text: e?.note ?? i?.note ?? '');
    _categoryId = e?.categoryId ?? 'food';
    _sourceId = i?.sourceId ?? incomeSources.first.id;
    _day = e?.day ?? i?.day ?? ref.read(todayProvider);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final now = DateTime.now();
    final note = _noteCtrl.text.trim();
    final cents = parseMoneyToCents(_amountCtrl.text)!;
    final day = dateOnly(_day);
    final expenses = ref.read(expenseRepositoryProvider);
    final incomes = ref.read(incomeRepositoryProvider);
    final budget = ref.read(budgetRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final oldExpense = widget.expense;
    final oldIncome = widget.income;

    try {
      if (_isIncome) {
        await incomes.save(Income(
          id: oldIncome?.id ?? _uuid.v4(),
          amountCents: cents,
          sourceId: _sourceId,
          note: note.isEmpty ? null : note,
          day: day,
          createdAt: oldIncome?.createdAt ?? oldExpense?.createdAt ?? now,
          updatedAt: now,
        ));
        // Switched an expense to income while editing.
        if (oldExpense != null) await expenses.delete(oldExpense.id);
      } else {
        await expenses.save(Expense(
          id: oldExpense?.id ?? _uuid.v4(),
          amountCents: cents,
          categoryId: _categoryId,
          note: note.isEmpty ? null : note,
          day: day,
          createdAt: oldExpense?.createdAt ?? oldIncome?.createdAt ?? now,
          updatedAt: now,
        ));
        if (oldIncome != null) await incomes.delete(oldIncome.id);
      }
      // An entry dated before setup stretches the first month back to it.
      await budget.extendTrackingStart(day);

      if (!mounted) return;
      Navigator.of(context).pop();
      if (_isIncome && !_isEditing) {
        messenger.showSnackBar(
          SnackBar(content: Text('Added ${formatMoney(cents)} to your overall budget')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save. Please try again. ($error)')),
      );
    }
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context) || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final expense = widget.expense;
    final income = widget.income;
    final expenses = ref.read(expenseRepositoryProvider);
    final incomes = ref.read(incomeRepositoryProvider);
    Navigator.of(context).pop();
    if (expense != null) {
      await deleteExpenseWithUndo(repo: expenses, messenger: messenger, expense: expense);
    } else if (income != null) {
      await deleteIncomeWithUndo(repo: incomes, messenger: messenger, income: income);
    }
  }

  Future<void> _pickDate(DateTime firstDate, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(firstDate) ? firstDate : _day,
      firstDate: firstDate,
      lastDate: today,
      helpText: _isIncome ? 'When did you receive it?' : 'When did you spend it?',
    );
    if (picked != null) setState(() => _day = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    // Any day in the past year (or the entry's own date if older), up to today.
    final yearAgo = DateTime(today.year - 1, today.month, today.day);
    final firstDate = _day.isBefore(yearAgo) ? _day : yearAgo;
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final isToday = isSameDay(_day, today);
    final isYesterday = isSameDay(_day, yesterday);

    final String title;
    if (_isEditing) {
      title = _isIncome ? 'Edit income' : 'Edit expense';
    } else {
      title = _isIncome ? 'Add income' : 'Add expense';
    }

    final choices = _isIncome ? incomeSources : categories;
    final selectedChoice = _isIncome ? _sourceId : _categoryId;

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(title, key: ValueKey(title)),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: AmbientBackground(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    _TypeToggle(
                      isIncome: _isIncome,
                      onChanged: (value) => setState(() => _isIncome = value),
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: _amountCtrl,
                      autofocus: !_isEditing,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [moneyInputFormatter],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: _isIncome ? AppColors.success : null,
                      ),
                      validator: validateAmount,
                      decoration: InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        hintText: '0.00',
                        hintStyle: theme.textTheme.displayMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        prefixText: _isIncome ? '+$kCurrency ' : '$kCurrency ',
                        prefixStyle: theme.textTheme.headlineSmall?.copyWith(
                          color: _isIncome ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                        ),
                        errorStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                    if (_isIncome)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Income is added to your overall budget.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Category or income source
                    Text(_isIncome ? 'From' : 'Category', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Wrap(
                        key: ValueKey(_isIncome),
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in choices)
                            _CategoryChoice(
                              category: c,
                              selected: c.id == selectedChoice,
                              onTap: () => setState(() {
                                if (_isIncome) {
                                  _sourceId = c.id;
                                } else {
                                  _categoryId = c.id;
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Date
                    Text('Date', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Today'),
                          selected: isToday,
                          onSelected: (_) => setState(() => _day = today),
                        ),
                        ChoiceChip(
                          label: const Text('Yesterday'),
                          selected: isYesterday,
                          onSelected: (_) => setState(() => _day = yesterday),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(isToday || isYesterday ? 'Pick a date' : DateFormat('EEE, d MMM').format(_day)),
                          selected: !isToday && !isYesterday,
                          onSelected: (_) => _pickDate(firstDate, today),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Note
                    Text('Note', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _noteCtrl,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        hintText: _isIncome ? 'e.g. PTPTN, part-time job (optional)' : 'What was it for? (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: GradientButton(
                    label: _isEditing ? 'Save changes' : (_isIncome ? 'Save income' : 'Save expense'),
                    icon: Icons.check_rounded,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glossy two-way switch: Expense | Income.
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.isIncome, required this.onChanged});

  final bool isIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = AppGradients.brand(theme.brightness);
    const green = [Color(0xFF1F9D6B), Color(0xFF3CC98F)];
    final colors = isIncome ? green : brand;

    Widget option(String label, IconData icon, bool value) {
      final selected = isIncome == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: Pressable(
            onTap: () => onChanged(value),
            scale: 0.96,
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          // Sliding gradient pill behind the selected option.
          Positioned.fill(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: isIncome ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              option('Expense', Icons.north_east_rounded, false),
              option('Income', Icons.south_west_rounded, true),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({required this.category, required this.selected, required this.onTap});

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(category.colorValue);
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.25)!])
                : null,
            color: selected ? null : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? Colors.transparent : theme.colorScheme.outlineVariant),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(categoryIcon(category.iconKey), size: 18, color: selected ? Colors.white : color),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: theme.textTheme.labelLarge?.copyWith(color: selected ? Colors.white : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
