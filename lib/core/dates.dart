import 'package:intl/intl.dart';

/// Strips the time, keeping only the calendar day (local time).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _two(int n) => n.toString().padLeft(2, '0');

/// "2026-11-05". Stored in the database so days never shift with time zones.
String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDayKey(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// "2026-11". One budget row exists per month key.
String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}';

/// Whole days from [a] to [b] (b - a), ignoring time and daylight saving.
int daysBetween(DateTime a, DateTime b) {
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ub.difference(ua).inDays;
}

DateTime lastDayOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today", "Yesterday", "Mon, 3 Nov", or "Mon, 3 Nov 2025" for other years.
String friendlyDay(DateTime day, DateTime today) {
  if (isSameDay(day, today)) return 'Today';
  if (isSameDay(day, today.subtract(const Duration(days: 1)))) return 'Yesterday';
  final pattern = day.year == today.year ? 'EEE, d MMM' : 'EEE, d MMM y';
  return DateFormat(pattern).format(day);
}

/// "5–30 Nov"
String rangeLabel(DateTime start, DateTime end) {
  final month = DateFormat('MMM').format(end);
  if (start.month == end.month && start.year == end.year) {
    return '${start.day}–${end.day} $month';
  }
  return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}';
}

String monthName(DateTime d) => DateFormat('MMMM').format(d);
