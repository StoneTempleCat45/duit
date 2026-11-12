import 'package:intl/intl.dart';

/// Currency symbol shown everywhere in the app. Change it here to switch currency.
const String kCurrency = 'RM';

/// Largest amount accepted in any money field (RM 1,000,000.00).
const int kMaxAmountCents = 100000000;

final NumberFormat _withCents = NumberFormat('#,##0.00', 'en_US');
final NumberFormat _wholeOnly = NumberFormat('#,##0', 'en_US');

/// Formats cents as money, e.g. 125050 -> "RM 1,250.50".
///
/// Money is stored as whole cents (int) everywhere so sums are exact.
/// With [compact], whole amounts drop the ".00" (e.g. "RM 500").
String formatMoney(int cents, {bool symbol = true, bool compact = false}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final number = (compact && abs % 100 == 0)
      ? _wholeOnly.format(abs ~/ 100)
      : _withCents.format(abs / 100);
  final text = symbol ? '$kCurrency $number' : number;
  return negative ? '-$text' : text;
}

/// Parses user input like "12", "12.5", "1,200.00" into cents.
/// Returns null when the text is not a valid amount.
int? parseMoneyToCents(String raw) {
  final s = raw.trim().replaceAll(',', '');
  if (s.isEmpty) return null;
  final match = RegExp(r'^(\d*)(?:\.(\d{0,2}))?$').firstMatch(s);
  if (match == null) return null;
  final whole = match.group(1) ?? '';
  final fraction = match.group(2) ?? '';
  if (whole.isEmpty && fraction.isEmpty) return null;
  if (whole.length > 9) return null;
  final wholeCents = int.parse(whole.isEmpty ? '0' : whole) * 100;
  final fractionCents = int.parse(fraction.padRight(2, '0'));
  return wholeCents + fractionCents;
}

/// Turns cents back into editable text, e.g. 1250 -> "12.50", 500 -> "5".
String centsToInput(int cents) {
  final whole = cents ~/ 100;
  final rest = cents % 100;
  return rest == 0 ? '$whole' : '$whole.${rest.toString().padLeft(2, '0')}';
}

/// Form validator for money fields.
String? validateAmount(String? raw) {
  final cents = parseMoneyToCents(raw ?? '');
  if (cents == null) return 'Enter an amount, like 12.50';
  if (cents <= 0) return 'Amount must be more than $kCurrency 0';
  if (cents > kMaxAmountCents) return 'That amount is too large';
  return null;
}
