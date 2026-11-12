import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/today_provider.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../budget/budget_widgets.dart';

/// First-run screen: asks for the overall budget and the monthly budget.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _overallCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _overallCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).completeSetup(
            overallCents: parseMoneyToCents(_overallCtrl.text)!,
            monthlyCents: parseMoneyToCents(_monthlyCtrl.text)!,
            today: ref.read(todayProvider),
          );
      // The app switches to the dashboard automatically once settings exist.
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your budget. Please try again. ($error)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final monthEnd = lastDayOfMonth(today);

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Duit'),
                  TextSpan(text: '.', style: TextStyle(color: theme.colorScheme.primary)),
                ]),
                style: theme.textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Set your budget once, then log spending in a few taps.',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 36),
              MoneyField(
                controller: _overallCtrl,
                label: 'Overall budget',
                hint: '1200',
                helper: 'All the money you have to spend. It runs down month by month.',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              MoneyField(
                controller: _monthlyCtrl,
                label: 'Monthly budget',
                hint: '500',
                helper: 'How much you plan to spend each month.',
                textInputAction: TextInputAction.done,
                extraValidator: (cents) {
                  final overall = parseMoneyToCents(_overallCtrl.text);
                  if (overall != null && cents > overall) {
                    return "Monthly budget can't be more than your overall budget";
                  }
                  return null;
                },
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your first month runs from today to ${monthEnd.day} ${monthName(monthEnd)}. '
                        'After that, each month starts on the 1st.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              GradientButton(
                label: 'Start tracking',
                icon: Icons.arrow_forward_rounded,
                onPressed: _saving
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _start();
                      },
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
