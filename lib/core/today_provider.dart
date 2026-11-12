import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dates.dart';

/// Today's date. Updates at midnight and whenever the app comes back to the
/// foreground, so a new day or a new month is picked up without a restart.
class TodayNotifier extends Notifier<DateTime> {
  Timer? _midnightTimer;

  @override
  DateTime build() {
    final listener = AppLifecycleListener(onResume: _refresh);
    ref.onDispose(() {
      _midnightTimer?.cancel();
      listener.dispose();
    });
    final now = DateTime.now();
    _scheduleMidnight(now);
    return dateOnly(now);
  }

  void _scheduleMidnight(DateTime now) {
    _midnightTimer?.cancel();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now) + const Duration(seconds: 1), _refresh);
  }

  void _refresh() {
    final now = DateTime.now();
    final today = dateOnly(now);
    if (today != state) state = today;
    _scheduleMidnight(now);
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);
