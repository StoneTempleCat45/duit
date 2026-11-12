import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../domain/budget_math.dart';
import '../features/budget/budget_providers.dart';

/// Full name of the Kotlin class that draws the widget
/// (android/app/src/main/kotlin/com/duitapp/duit/DuitWidgetProvider.kt).
const _androidWidget = 'com.duitapp.duit.DuitWidgetProvider';

/// Keeps the home screen widget in sync with the app.
///
/// It listens to the budget summary, which changes whenever an expense is
/// added, edited or deleted, a budget changes, or a new day starts. Each
/// change is saved for the widget and the widget is redrawn.
///
/// Watch this provider once near the top of the app to switch it on.
final widgetSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<BudgetSummary?>>(
    budgetSummaryProvider,
    (previous, next) {
      if (!next.hasValue) return;
      final isSetUp = ref.read(settingsProvider).value != null;
      _pushToWidget(isSetUp: isSetUp, summary: next.value);
    },
    fireImmediately: true,
  );
});

Future<void> _pushToWidget({required bool isSetUp, BudgetSummary? summary}) async {
  final now = DateTime.now();
  final data = <String, String>{
    'ready': isSetUp ? 'true' : 'false',
    'day': dayKey(summary?.today ?? now),
    'month': monthKey(summary?.today ?? now),
    'zero': formatMoney(0),
  };

  if (!isSetUp) {
    data.addAll({
      'today': formatMoney(0),
      'left': 'Set up Duit',
      'left_label': 'Tap to set your budget',
      'caption': '',
      'percent': '0',
      'level': '0',
    });
  } else if (summary == null) {
    data.addAll({
      'today': formatMoney(0),
      'left': 'No budget yet',
      'left_label': 'Set a budget for ${monthName(now)}',
      'caption': 'Tap to open Duit',
      'percent': '0',
      'level': '0',
    });
  } else {
    final over = summary.remainingCents < 0;
    data.addAll({
      'today': formatMoney(summary.todayCents),
      'left': formatMoney(summary.remainingCents.abs()),
      'left_label': over ? 'over budget this month' : 'left this month',
      'caption': '${summary.usedPercent}% used · ${formatMoney(summary.dailyAllowanceCents)}/day',
      'percent': '${summary.usedPercent.clamp(0, 100)}',
      'level': '${summary.level.index}',
    });
  }

  try {
    for (final entry in data.entries) {
      await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: _androidWidget);
  } catch (error) {
    // The widget is optional; never let it break the app (e.g. in tests).
    debugPrint('Home widget update failed: $error');
  }
}
