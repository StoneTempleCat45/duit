import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/today_provider.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../budget/budget_providers.dart';
import '../budget/budget_widgets.dart';

/// Change this month's budget and the overall budget, or reset.
class BudgetSettingsScreen extends ConsumerStatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  ConsumerState<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends ConsumerState<BudgetSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _monthlyCtrl;
  late final TextEditingController _overallCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final month = ref.read(currentMonthBudgetProvider).value;
    final settings = ref.read(settingsProvider).value;
    _monthlyCtrl = TextEditingController(text: month == null ? '' : centsToInput(month.amountCents));
    _overallCtrl = TextEditingController(text: settings == null ? '' : centsToInput(settings.overallCents));
  }

  @override
  void dispose() {
    _monthlyCtrl.dispose();
    _overallCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.setMonthBudget(ref.read(currentMonthKeyProvider), parseMoneyToCents(_monthlyCtrl.text)!);
      await repo.updateOverall(parseMoneyToCents(_overallCtrl.text)!);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Budget saved')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save. Please try again. ($error)')));
    }
  }

  Future<void> _startNewOverall() async {
    final current = parseMoneyToCents(_overallCtrl.text);
    final cents = await showDialog<int>(
      context: context,
      builder: (_) => _NewOverallDialog(initialCents: current),
    );
    if (cents == null || !mounted) return;
    await ref.read(budgetRepositoryProvider).startNewOverall(
          overallCents: cents,
          today: ref.read(todayProvider),
        );
    if (!mounted) return;
    _overallCtrl.text = centsToInput(cents);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('New overall budget of ${formatMoney(cents, compact: true)} starts today')),
    );
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: scheme.error),
          title: const Text('Delete all data?'),
          content: const Text(
            'This permanently deletes every expense and budget on this phone. '
            "You can't undo this. The app will start again from setup.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete everything'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(budgetRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    await repo.deleteAllData();
    messenger.showSnackBar(const SnackBar(content: Text('All data deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final settings = ref.watch(settingsProvider).value;
    final overallSpent = ref.watch(overallSpentProvider).value ?? 0;
    final dateFormat = DateFormat('d MMM y');

    return Scaffold(
      appBar: AppBar(title: const Text('Budget settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            MoneyField(
              controller: _monthlyCtrl,
              label: 'Budget for ${monthName(today)}',
              hint: '500',
              helper: 'Next month starts with the same amount. You can change it any time.',
              textInputAction: TextInputAction.next,
              extraValidator: (cents) {
                final overall = parseMoneyToCents(_overallCtrl.text);
                if (overall != null && cents > overall) {
                  return "Monthly budget can't be more than your overall budget";
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            MoneyField(
              controller: _overallCtrl,
              label: 'Overall budget',
              hint: '1200',
              helper: 'Raise this when you add more money to your current budget.',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            if (settings != null)
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This overall budget started on ${dateFormat.format(settings.potStart)}. '
                        'You have spent ${formatMoney(overallSpent)} of it so far.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            GradientButton(label: 'Save budget', icon: Icons.check_rounded, onPressed: _saving ? null : _save),

            const SizedBox(height: 40),
            const Eyebrow('Reset'),
            const SizedBox(height: 10),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ResetTile(
                    icon: Icons.restart_alt_rounded,
                    title: 'Start a new overall budget',
                    subtitle: 'Your overall budget counts again from today. '
                        'Past expenses stay in your history.',
                    onTap: _startNewOverall,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _ResetTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete all data',
                    subtitle: 'Remove every expense and budget and start over.',
                    color: scheme.error,
                    onTap: _deleteAll,
                  ),
                ],
              ),
            ),
            if (settings != null) ...[
              const SizedBox(height: 12),
              Text(
                'Tracking since ${dateFormat.format(settings.trackingStart)}.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResetTile extends StatelessWidget {
  const _ResetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(icon, color: color ?? theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: color)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

/// Asks for the amount of the new overall budget. Returns cents, or null.
class _NewOverallDialog extends StatefulWidget {
  const _NewOverallDialog({this.initialCents});

  final int? initialCents;

  @override
  State<_NewOverallDialog> createState() => _NewOverallDialogState();
}

class _NewOverallDialogState extends State<_NewOverallDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialCents == null ? '' : centsToInput(widget.initialCents!),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, parseMoneyToCents(_ctrl.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start a new overall budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Spending from today counts against this amount.'),
            const SizedBox(height: 16),
            MoneyField(
              controller: _ctrl,
              label: 'New overall budget',
              hint: '1200',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Start')),
      ],
    );
  }
}
