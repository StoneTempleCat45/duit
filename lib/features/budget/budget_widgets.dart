import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';

/// Allows digits with at most one dot and two decimals, e.g. "1250.50".
final moneyInputFormatter = FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?'));

/// A labelled money text field with validation.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.extraValidator,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;

  /// Runs after the basic checks pass, with the parsed amount in cents.
  final String? Function(int cents)? extraValidator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [moneyInputFormatter],
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style: theme.textTheme.titleLarge,
          decoration: InputDecoration(
            prefixText: '$kCurrency  ',
            prefixStyle: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            hintText: hint,
            helperText: helper,
            helperMaxLines: 2,
            errorMaxLines: 2,
          ),
          validator: (value) {
            final basic = validateAmount(value);
            if (basic != null) return basic;
            return extraValidator?.call(parseMoneyToCents(value!)!);
          },
        ),
      ],
    );
  }
}
