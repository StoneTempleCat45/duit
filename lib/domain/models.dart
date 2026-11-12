/// Plain Dart models used by the UI.
///
/// These do not depend on Drift, so the storage layer can be swapped or
/// extended (for example with cloud sync) without touching the screens.
library;

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    this.sortOrder = 0,
  });

  /// Stable text id such as "food", so it matches across devices if synced.
  final String id;
  final String name;
  final String iconKey;
  final int colorValue;
  final int sortOrder;
}

class Expense {
  const Expense({
    required this.id,
    required this.amountCents,
    required this.categoryId,
    required this.day,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  /// UUID, so records can be merged with a server later without clashes.
  final String id;
  final int amountCents;
  final String categoryId;
  final String? note;

  /// The calendar day the money was spent (no time part).
  final DateTime day;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Money coming in. It adds to the overall budget.
class Income {
  const Income({
    required this.id,
    required this.amountCents,
    required this.sourceId,
    required this.day,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final int amountCents;

  /// One of [incomeSources], e.g. "allowance".
  final String sourceId;
  final String? note;
  final DateTime day;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// The overall budget: a pot of money that runs down across months.
class BudgetSettings {
  const BudgetSettings({
    required this.overallCents,
    required this.trackingStart,
    required this.potStart,
    required this.updatedAt,
  });

  final int overallCents;

  /// The day tracking began. The first month runs from this day to the end
  /// of that month.
  final DateTime trackingStart;

  /// The day the current overall budget started. Spending from this day
  /// counts against it. Moves to today when you start a new overall budget.
  final DateTime potStart;
  final DateTime updatedAt;
}

class MonthlyBudget {
  const MonthlyBudget({
    required this.month,
    required this.amountCents,
    required this.carriedOver,
    required this.warned80,
    required this.warned100,
  });

  /// "2026-11"
  final String month;
  final int amountCents;

  /// True when the amount was copied from last month automatically and the
  /// user has not confirmed it yet (shows the "new month" banner).
  final bool carriedOver;
  final bool warned80;
  final bool warned100;
}
